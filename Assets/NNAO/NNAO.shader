Shader "Hidden/NNAO"
{
    Properties
    {
        _MainTex("", 2D) = "" {}
        _F0Tex("", 2D) = "" {}
        _F1Tex("", 2D) = "" {}
        _F2Tex("", 2D) = "" {}
        _F3Tex("", 2D) = "" {}
    }
    SubShader
    {
        Cull Off ZWrite Off ZTest Always
        Pass
        {
            CGPROGRAM
            #pragma vertex vert_img
            #pragma fragment frag
            #include "NNAO.cginc"
            ENDCG
        }
    }
}
