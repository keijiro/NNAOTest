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

        #endregion

        #region Built-in resources

        void Update()
        {
            GetComponent<Camera>().depthTextureMode |=
                DepthTextureMode.Depth | DepthTextureMode.DepthNormals;
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

            Graphics.Blit(source, dest, _material, 0);
        }

        #endregion
    }
}
