using UnityEngine;

namespace NNAO
{
    [ExecuteInEditMode]
    [RequireComponent(typeof(Camera))]
    public sealed class AmbientOcclusion : MonoBehaviour
    {
        #region Exposed attributes

        [SerializeField] float _radius = 1;

        #endregion

        #region Built-in resources

        [SerializeField, HideInInspector] Shader _nnaoShader;

        [SerializeField, HideInInspector] Texture2D _f0Texture;
        [SerializeField, HideInInspector] Texture2D _f1Texture;
        [SerializeField, HideInInspector] Texture2D _f2Texture;
        [SerializeField, HideInInspector] Texture2D _f3Texture;

        #endregion

        #region Private members

        Material _material;
        RenderTexture _feedbackRT;

        #endregion

        #region Built-in resources

        void OnDestroy()
        {
            if (_material != null)
            {
                if (Application.isPlaying)
                    Destroy(_material);
                else
                    DestroyImmediate(_material);
            }

            if (_feedbackRT != null)
                RenderTexture.ReleaseTemporary(_feedbackRT);
        }
        
        void Update()
        {
            GetComponent<Camera>().depthTextureMode |= DepthTextureMode.DepthNormals;
        }

        void OnRenderImage(RenderTexture source, RenderTexture dest)
        {
            if (_material == null)
            {
                _material = new Material(_nnaoShader);
                _material.hideFlags = HideFlags.DontSave;
            }

            _material.SetTexture("_F0Tex", _f0Texture);
            _material.SetTexture("_F1Tex", _f1Texture);
            _material.SetTexture("_F2Tex", _f2Texture);
            _material.SetTexture("_F3Tex", _f3Texture);
            _material.SetFloat("_Radius", _radius);
            _material.SetInt("_FrameCount", Time.frameCount);

            var tempRT = RenderTexture.GetTemporary(
                source.width, source.height, 0, RenderTextureFormat.RHalf);

            Graphics.Blit(_feedbackRT, tempRT, _material, 0);
            Graphics.Blit(tempRT, dest, _material, 1);

            if (_feedbackRT != null)
                RenderTexture.ReleaseTemporary(_feedbackRT);
            _feedbackRT = tempRT;
        }

        #endregion
    }
}
