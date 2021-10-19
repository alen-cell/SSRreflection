Shader "Custom/DebugMask"
{
    Properties
    {
        _MainTex("Color", Color) = (1,1,1,1)
       
    }
        SubShader
        {

          Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalRenderPipeline""IgnoreProjector" = "True" }

            HLSLINCLUDE
             #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"



             TEXTURE2D(_Mask);
             SAMPLER(sampler_Mask);

            ENDHLSL

                Pass//写入场景物体深度
            {
                Name "SceneDepthOnly"
                Tags{"LightMode" = "UniversalForward"}
                ZTest on
                ZWrite on
                Cull back
              

                 HLSLPROGRAM

             #pragma vertex vert
          #pragma fragment frag

 struct a2v
 {
     float4 positionOS: POSITION;
 };

 struct v2f
 {
     float4 positionCS: SV_POSITION;
 };


 v2f vert(a2v v)
 {
     v2f o;

     o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
     return o;
 }

 half4 frag(v2f i) : SV_Target
 {
     return (0,0,0,0);
 }
 ENDHLSL


            }
              Pass{

                           Name"Mask"


                           Tags{
                                   "LightMode" = "UniversalForward"}

                        
                ZTest on
                ZWrite on
                Cull back
                    

                           HLSLPROGRAM

                           #pragma vertex vert_mask
               #pragma fragment frag_mask

                      struct a2v {
                           float4 positionOS:POSITION;
                      };
                       struct v2f {
                           float4 positionHCS : SV_POSITION;
                       };


                       v2f vert_mask(a2v v)
                       {
                           v2f o;

                          o.positionHCS = TransformObjectToHClip(v.positionOS);
                          return o;

                   }
                       half4 frag_mask(v2f i) :SV_Target
                       {
                           return float4(1,1,1,1);

                       }

               ENDHLSL
                       }

             

        }
}
