#include "UnityCG.cginc"

sampler2D _CameraDepthTexture;
sampler2D _CameraDepthNormalsTexture;

sampler2D _MainTex;
sampler2D _F0Tex;
sampler2D _F1Tex;
sampler2D _F2Tex;
sampler2D _F3Tex;

float _Radius;
uint _FrameCount;

static const float4 F0a = float4( 2.364370,  2.399485,  0.889055,  4.055205);
static const float4 F0b = float4(-1.296360, -0.926747, -0.441784, -3.308158);
static const float4 F1a = float4( 1.418117,  1.505182,  1.105307,  1.728971);
static const float4 F1b = float4(-0.491502, -0.789398, -0.328302, -1.141073);
static const float4 F2a = float4( 1.181042,  1.292263,  2.136337,  1.616358);
static const float4 F2b = float4(-0.535625, -0.900996, -0.405372, -1.030838);
static const float4 F3a = float4( 1.317336,  2.012828,  1.945621,  5.841383);
static const float4 F3b = float4(-0.530946, -1.091267, -1.413035, -3.908190);

static const float4 Xmean = float4( 0.000052, -0.000003, -0.000076,  0.004600);
static const float4 Xstd  = float4( 0.047157,  0.052956,  0.030938,  0.056321);
static const float Ymean = 0.000000;
static const float Ystd  = 0.116180;

static const float4x4 W1 = float4x4(
    -0.147624, -0.150471,  0.154306, -0.006904,
     0.303306,  0.057305, -0.240071,  0.036727,
     0.009158, -0.371759, -0.259837,  0.302215,
    -0.111847, -0.183312,  0.044680, -0.190296
 );

static const float4x4 W2 = float4x4(
     0.212815,  0.028991,  0.105671, -0.111834,
     0.316173, -0.166099,  0.058121, -0.170316,
     0.135707, -0.478362, -0.156021, -0.413203,
    -0.097283,  0.189983,  0.019879, -0.260882
);

static const float4 W3 = float4( 0.774455,  0.778138, -0.318566, -0.523377);

static const float4 b0 = float4( 0.428451,  2.619065,  3.756697,  1.636395);
static const float4 b1 = float4( 0.566310,  1.877808,  1.316716,  1.091115);
static const float4 b2 = float4( 0.033848,  0.036487, -1.316707, -1.067260);
static const float  b3 = 0.151472;

static const float4 alpha0 = float4( 0.326746, -0.380245,  0.179183,  0.104307);
static const float4 alpha1 = float4( 0.255981,  0.009228,  0.211068,  0.110055);
static const float4 alpha2 = float4(-0.252365,  0.016463, -0.232611,  0.069798);
static const float  alpha3 = -0.553760;

static const float4 beta0 = float4( 0.482399,  0.562806,  0.947146,  0.460560);
static const float4 beta1 = float4( 0.670060,  1.090481,  0.461880,  0.322837);
static const float4 beta2 = float4( 0.760696,  1.016398,  1.686991,  1.744554);
static const float  beta3 = 0.777760;

// Depth/normal sampling functions
float SampleDepth(float2 uv)
{
    float4 cdn = tex2D(_CameraDepthNormalsTexture, uv);
    return DecodeFloatRG(cdn.zw) * _ProjectionParams.z;
}

float3 SampleNormal(float2 uv)
{
    float4 cdn = tex2D(_CameraDepthNormalsTexture, uv);
    return DecodeViewNormalStereo(cdn) * float3(1, 1, -1);
}

float4 SampleDepthNormal(float2 uv)
{
    float4 cdn = tex2D(_CameraDepthNormalsTexture, uv);
    float3 normal = DecodeViewNormalStereo(cdn) * float3(1, 1, -1);
    float depth = DecodeFloatRG(cdn.zw) * _ProjectionParams.z;
    return float4(normal, depth);
}

float3 ReconstructViewPosition(float2 uv, float depth)
{
    const float2 p11_22 = float2(unity_CameraProjection._11, unity_CameraProjection._22);
    const float2 p13_31 = float2(unity_CameraProjection._13, unity_CameraProjection._23);
    return float3((uv * 2 - 1 - p13_31) / p11_22 * depth, depth);
}

float3 rand(float3 seed)
{
    float x = sin(dot(seed, float3(12.9898, 78.233, 21.317)));
    return frac(x * float3(43758.5453, 21383.21227, 20431.20563)) * 2 - 1;
}

float prelu(float x, float alpha, float beta)
{
    return beta * max(x, 0) + alpha * min(x, 0);
}

float4 prelu(float4 x, float4 alpha, float4 beta)
{
    return beta * max(x, 0) + alpha * min(x, 0);
}

float2 spiral(float t1, float t2, float l, float o)
{
    float x = l * 2 * UNITY_PI * (t1 + o);
    return t2 * float2(cos(x), sin(x));
}

half AO(float4 midl, float3 base, float seed, float seed2)
{
    // Sample count
    const int NSAMPLES = 10;

    // Full/half filter width
    const int FW = 31;
    const int HW = (FW - 1) / 2;

    // First Layer
    float4 H0 = 0;

    // New Faster Sampler Method
    for (int i = 0; i < NSAMPLES; i++)
    {
        float t1 = (float)(i +     1) / (NSAMPLES + 1);
        float t2 = (float)(i + seed2) / (NSAMPLES + 1);

        float scale = UNITY_PI * FW * FW * t2 / (NSAMPLES * 2);
        float2 indx = spiral(t1, t2, 1.8, seed);

        float4 next = float4(base.xy + indx * _Radius, base.z, 1);
        next = mul(unity_CameraProjection, next);

        float2 next_uv = (next.xy / base.z + 1) / 2;
        float4 norm = SampleDepthNormal(next_uv);

        float3 actu = ReconstructViewPosition(next_uv, norm.w);
        float2 fltr = (indx * HW + HW + 0.5) / (HW * 2 + 2);

        float4 X = float4(norm.xyz - midl.xyz, (actu.z - base.z) / _Radius);
        X *= saturate(1 - distance(actu, base) / _Radius);

        X.xzw = -X.xzw;

        float4x4 m = float4x4(
            tex2D(_F0Tex, fltr) * F0a + F0b,
            tex2D(_F1Tex, fltr) * F1a + F1b,
            tex2D(_F2Tex, fltr) * F2a + F2b,
            tex2D(_F3Tex, fltr) * F3a + F3b
        );

        H0 += scale * mul(m, (X - Xmean) / Xstd);
    }

    H0 = prelu(H0 + b0, alpha0, beta0);

    // Other Layers
    float4 H1 = prelu(mul(transpose(W1), H0) + b1, alpha1, beta1);
    float4 H2 = prelu(mul(transpose(W2), H1) + b2, alpha2, beta2);
    float  Y  = prelu(dot(W3, H2) + b3, alpha3, beta3);

    return Y * Ystd + Ymean;
}

half4 frag_ao(v2f_img i) : SV_Target
{
    uint2 sc = i.uv * _ScreenParams;

    float4 midl = SampleDepthNormal(i.uv);
    float3 base = ReconstructViewPosition(i.uv, midl.w);
    float3 seed = rand(base);

    static const float rotations[6] = { 60, 300, 180, 240, 120, 0 };
    static const float offsets[4] = { 0, 0.5, 0.25, 0.75 };

    float offs = _Time.y;
    float ao = AO(midl, base,
        frac((1.0 / 16.0) * ((((sc.x + sc.y) & 3) << 2) + (sc.x & 3)) +
            rotations[_FrameCount % 6] / 360),
        frac((1.0 / 4.0) * ((sc.y - sc.x) & 3) + offsets[(_FrameCount / 6) % 4])
    );

    float hist = tex2D(_MainTex, i.uv).r;
    return lerp(hist, saturate(ao), 0.02);
}

half4 frag_composite(v2f_img i) : SV_Target
{
    float ao = tex2D(_MainTex, i.uv).r;
    return half4(GammaToLinearSpace(saturate(1 - ao)), 1);
}
