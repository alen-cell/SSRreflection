Shader "MyURP/URPssr"
{
    Properties
    {
      
        _MainTex("MainTex",2D) ="white" {}
        _maxRayMarchingDistance("maxRayMarchingDistance",Range(0,100)) = 100
        _maxRayMarchingStep("maxRayMarchingStep",Range(0,100)) = 100
        _rayMarchingStepSize("rayMarchingStepSize",Range(0,1)) = 0.1
        _maxRayMarchingBianrySearchCount("maxRayMarchingBinarySearchCount",Range(0,10)) = 10
       _depthThickness("depthThickness",Range(0,50)) = 4
        _BlurSize("BlurSize",Range(0,2)) = 1
          
    }

        SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

         

         HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
         #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" 
            CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;

        //RayMarching
        float _maxRayMarchingBianrySearchCount;
        float _maxRayMarchingDistance;
        float _maxRayMarchingStep;
        float _rayMarchingStepSize;
        float _depthThickness;

        //blur
        float _BlurSize;
        float4 _MainTex_TexelSize;
        float4 _offsets;
            CBUFFER_END

               //sampler
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D_X_FLOAT(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
            TEXTURE2D(_CameraDepthNormalsTexture);
            SAMPLER(sampler_CameraDepthNormalsTexture);
            TEXTURE2D(_ditherMap);
            SAMPLER(sampler_ditherMap);
             TEXTURE2D(_Mask);
             SAMPLER(sampler_Mask);
             TEXTURE2D(_ReflectTex);
             SAMPLER(sampler_ReflectTex);
             TEXTURE2D(_SourTex);

             SAMPLER(sampler_SourTex);

            //判断当前反射点是否在屏幕外，或超出了深度值
           


            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
                float3 normalOS:NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv           : TEXCOORD0;
                float3 viewRay:TEXCOORD1;
                float3 normalVS :TEXCOORD2;

            };




            ENDHLSL


        Pass
        {

                Name"ReflectPass"
           ZTest Off
           //Zwrite Off
          
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
              
           
                //解码深度贴图
          //   inline float DecodeFloatRG(float2 enc)
          //  {
          //      float2 kDecodeDot = float2(1.0, 1 / 255.0);
            //     return dot(enc, kDecodeDot);
            //    }
            //解码法线贴图函数

             inline float3 DecodeViewNormalStereo(float4 enc4)
             {
                 float kScale = 1.7777;
                 float3 nn = enc4.xyz * float3(2 * kScale, 2 * kScale, 0) + float3(-kScale, -kScale, 1);
                 float g = 2.0 / dot(nn.xyz, nn.xyz);
                 float3 n;
                 n.xy = g * nn.xy;
                 n.z = g - 1;
                 return n;
             }


              bool checkDepthCollision(float3 viewPos, out float2 screenPos,inout float depthDistance) {
                //将视空间的值变换到裁剪空间，计算屏幕空间的采样位置
                float4 clipPos = mul(unity_CameraProjection, float4(viewPos, 1.0));
                 //裁剪空间齐次除法
                 clipPos = clipPos / clipPos.w;

                 //变换到屏幕空间
                 screenPos = float2(clipPos.x, clipPos.y) * 0.5 + 0.5;

                 float4 depthnormalTex = SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, screenPos);
                 
                 float4 depthcolor = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture,screenPos);
                 float depth = LinearEyeDepth(depthcolor, _ZBufferParams)+ 0.2;
                
                 return screenPos.x > 0 && screenPos.y > 0 && screenPos.x < 1.0 && screenPos.y < 1.0 && (depth < -viewPos.z) && depth+_depthThickness>-viewPos.z;
           }


             bool viewSpaceRayMarching(float3 rayOri, float3 rayDir,float currentRayMarchingStepSize,inout float depthDistance,inout float3 currentViewPos,inout float2 hitScreenPos,float2 ditherUV) {
                float2 offsetUV = fmod(floor(ditherUV),4.0);
                float ditherValue = SAMPLE_TEXTURE2D(_ditherMap, sampler_ditherMap,offsetUV * 0.25).a;
                rayOri += ditherValue * rayDir;


                 
                 
                 
                 int maxStep = _maxRayMarchingStep;

                 UNITY_LOOP
                 for (int i = 0; i < maxStep; i++) {
                     float3 currentPos = rayOri + rayDir * currentRayMarchingStepSize * i;

                    if (length(rayOri - currentPos) > _maxRayMarchingDistance)
                         return false;
                    if (checkDepthCollision(currentPos, hitScreenPos, depthDistance)) {
                        currentViewPos = currentPos;
                        return true;
                      }
                    }
                 return false;
             }


          



             //搜索法
             bool binarySearchRayMarching(float3 rayOri,float3 rayDir,inout float2 hitScreenPos,float2 ditherUV)
             {
                 float currentStepSize = _rayMarchingStepSize;
                 float3 currentPos = rayOri;
                 float depthDistance = 0;
   
                 UNITY_LOOP
                     for (int i = 0; i < _maxRayMarchingBianrySearchCount; i++) {
                         if (viewSpaceRayMarching(rayOri, rayDir, currentStepSize, depthDistance, currentPos, hitScreenPos,ditherUV))
                         {
                             if (depthDistance < _depthThickness)
                             {
                                 return true;
                             }
                             //在原点重新步进，并且currentStepSize减小一半
                             rayOri = currentPos - rayDir * currentStepSize;
                                 currentStepSize *= 0.5;
                         }

                         else
                         {
                             return false;
                         }
                     }
                 
                 return false;
                                 

}





            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                float4 clipPos;
                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);

                 clipPos = float4(IN.uv * 2 - 1.0, 1.0, 1.0);
                float4 viewRay = mul(unity_CameraInvProjection, clipPos);
                //归一化设备坐标
                OUT.viewRay = viewRay.xyz / viewRay.w;
               
                return OUT;
            }


            half4 frag(Varyings IN) : SV_Target
            {
                half4 mainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
               

                float3 viewNormal = DecodeViewNormalStereo(SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, IN.uv));
                
               //解码得到Linear01Depth和视空间下的法线值
                float4 depthnormalTex = SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, IN.uv);
               
                float4 depthcolor = SAMPLE_TEXTURE2D_X(_CameraDepthTexture, sampler_CameraDepthTexture, IN.uv);
                float linear01Depth = Linear01Depth(depthcolor, _ZBufferParams);
       


                //重建视空间下点的坐标
                float3 positionVS = linear01Depth *IN.viewRay;

                viewNormal = normalize(viewNormal);
                float3 viewDir = normalize(positionVS);

                float2 hitScreenPos = float2(0, 0);
                //计算反射方向
                float3 reflectDir =normalize(reflect(viewDir, viewNormal));
                
                float4 reflectTexMap = (0, 0, 0, 0);

                //Ray Marching***
                if (binarySearchRayMarching(positionVS, reflectDir, hitScreenPos,IN.uv))
                {
                   float4 reflectTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex,hitScreenPos);
                   float ditherValue = SAMPLE_TEXTURE2D(_ditherMap, sampler_ditherMap, IN.uv * 0.25).a;
                   //mainTex.r = ditherValue;
                   float mask = SAMPLE_TEXTURE2D(_Mask, sampler_Mask, IN.uv);
    
                   
                   reflectTexMap.rgb += reflectTex.rgb;
                  
                    
               }
   
                  return reflectTexMap;
              
            }
            ENDHLSL
        }

        //blur

        Pass{
            Name"Blur"
            //ZTest Off
            //Cull Off
           // ZWrite Off

           
            HLSLPROGRAM

    
           
            #pragma vertex vert_blur
            #pragma fragment frag_blur

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
           
            struct v2f_blur
            {
                float4 positionHCS:SV_POSITION;
                float2 uv:TEXCOORD0;
                float4 uv01:TEXCOORD1;
                float4 uv23:TEXCOORD2;
                float4 uv45:TEXCOORD3;
            };

           


            v2f_blur vert_blur(Attributes v) {
                v2f_blur o;
                _offsets = _MainTex_TexelSize.xyxy;
                o.positionHCS = TransformObjectToHClip(v.positionOS);
                o.uv = v.uv;

                //对邻近区域使用的纹理坐标
                o.uv01 = v.uv.xyxy + _BlurSize * _offsets.xyxy * float4(1, 1, -1, -1);
                o.uv23 = v.uv.xyxy + _BlurSize * _offsets.xyxy * float4(1, 1, -1, -1) * 2.0;
                o.uv45 = v.uv.xyxy + _BlurSize * _offsets.xyxy * float4(1, 1, -1, -1) * 3.0;

                return o;

            }

            //计算进行滤波后的颜色
            half4 frag_blur(v2f_blur i) :SV_Target
            {

                half4 color = half4(0,0,0,0);
                color += 0.40 * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);
                color += 0.15 * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv01.xy);
                color += 0.15 * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv01.zw);
                color += 0.10 * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex,i.uv23.xy);
                color += 0.10 * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv23.zw);
                color += 0.05 * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex,i.uv45.xy);
                color += 0.05 * SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv45.zw);
                
                float mask = SAMPLE_TEXTURE2D(_Mask, sampler_Mask, i.uv);
                return color * mask;
               

            }

            


            

            ENDHLSL
            
        }

     

                Pass//写入场景物体深度Pass2
            {
                Name "SceneDepthOnly"
                Tags{"LightMode" = "UniversalForward"}
                ZTest on
                ZWrite on
                Cull back


                 HLSLPROGRAM

             #pragma vertex vert_depth
          #pragma fragment frag_depth

 struct a2v
 {
     float4 positionOS: POSITION;
 };

 struct v2f
 {
     float4 positionCS: SV_POSITION;
 };


 v2f vert_depth(a2v v)
 {
     v2f o;

     o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
     return o;
 }

 half4 frag_depth(v2f i) : SV_Target
 {
     return (0,0,0,0);
 }
 ENDHLSL


            }
    
                    
                    
         Pass{
     
     //pass3

                   Name"Mask"//Pass3

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
                             float2 uv           : TEXCOORD0;
                        };
                         struct v2f {
                             float4 positionHCS : SV_POSITION;
                             float2 uv           : TEXCOORD0;
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

     
     Pass{

         Name"Mix"//Pass4

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

                        o.positionHCS = TransformObjectToHClip(v.positionOS);
                        o.uv = v.uv;
                        return o;

                 }





                     half4 frag_final(v2f i) :SV_Target
                     {

                        half4 mainTex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv);
                        half4 reflectTex = SAMPLE_TEXTURE2D(_ReflectTex,sampler_ReflectTex,i.uv);
                        half4 sourTex = SAMPLE_TEXTURE2D(_SourTex, sampler_SourTex, i.uv);
                      
                      
                       
                        return
                            lerp(sourTex, reflectTex, reflectTex);
                               
                       



                     }

                                         ENDHLSL
                 }



    }



}
