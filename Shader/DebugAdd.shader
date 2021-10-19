Shader "Custom/DebugMix"
{
    Properties
    {
        _MainTex("Color", Color) = (1,1,1,1)
        _ReflectTex("Refelct Map", 2D) = "black"{}

    }
        SubShader
    {

      Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline""IgnoreProjector" = "True" }

        HLSLINCLUDE
         #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"



         TEXTURE2D(_MainTex);
         SAMPLER(sampler_MainTex);
         TEXTURE2D(_ReflectTex);
         SAMPLER(sampler_ReflectTex);

        ENDHLSL

            Pass{

           Name"Mix"//Pass3

                  Tags{
                                "LightMode" = "UniversalForward"}




              ZTest Off
              Cull Off
              ZWrite Off
              Fog{ Mode Off }


                HLSLPROGRAM

                #pragma vertex vert_final
               #pragma fragment frag_final

                      struct a2v {
                           float4 positionOS:POSITION;
                           float2 uv           : TEXCOORD0;

                      };
                       struct v2f {
                           float4 positionHCS : SV_POSITION;
                           float2 uv           : TEXCOORD0;
                       };


                       v2f vert_final(a2v v)
                       {
                           v2f o;
                           o.uv = v.uv;
                          o.positionHCS = TransformObjectToHClip(v.positionOS);
                          return o;

                   }





                       half4 frag_final(v2f i) :SV_Target
                       {
                          half4 mainTex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv);
                          half4 reflectTex = SAMPLE_TEXTURE2D(_ReflectTex,sampler_ReflectTex,i.uv);

                          // float depthcolor = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, i.uv);
                            return reflectTex+ mainTex;



                        }

                                            ENDHLSL
        }


    }
}
