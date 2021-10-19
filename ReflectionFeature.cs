
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ReflectionFeature : ScriptableRendererFeature {
    class ReflectionPass : ScriptableRenderPass
    {
        private RenderTargetIdentifier source { get; set; }
        private RenderTargetHandle destination {get; set;}
        public Material reflectionMaterial = null;
        RenderTargetHandle MainTexID;
        RenderTargetHandle BlurID;
        RenderTargetHandle ReflectID;
        RenderTargetHandle MaskID;
        RenderTargetHandle SourID;
    
        FilteringSettings filter;
        FilteringSettings filterDepth;
        public ReflectionSettings settings;
        ShaderTagId shaderTag = new ShaderTagId("UniversalForward");



        public void Setup(RenderTargetIdentifier source,RenderTargetHandle destination)
    {
        this.source = source;
        this.destination = destination;
    }

    public ReflectionPass(ReflectionSettings settings,Material reflectionMaterial)
    {
        this.settings = settings;
        this.reflectionMaterial = reflectionMaterial;
        SourID.Init("_SourTex");
        ReflectID.Init("_ReflectTex");
        MainTexID.Init("_MainTex");
        MaskID.Init("_Mask");


        RenderQueueRange queue = new RenderQueueRange();
        queue.lowerBound = Mathf.Min(settings.QueueMin);
        queue.upperBound = Mathf.Max(settings.QueueMax);
        filter = new FilteringSettings(queue, settings.Reflection);
        filterDepth = new FilteringSettings(queue, settings.Depth);
    }


    public override void Configure(CommandBuffer cmd,RenderTextureDescriptor cameraTextureDescriptor)
    {
            RenderTextureDescriptor desc = cameraTextureDescriptor;
            cmd.GetTemporaryRT(MaskID.id, desc);
            ConfigureTarget(MaskID.id);
            ConfigureClear(ClearFlag.All, Color.black);
        }

        // Here you can implement the rendering logic.
        // Use <c>ScriptableRenderContext</c> to issue drawing commands or execute command buffers
        // https://docs.unity3d.com/ScriptReference/Rendering.ScriptableRenderContext.html
        // You don't have to call ScriptableRenderContext.submit, the render pipeline will call it at specific points in the pipeline.
        public override void Execute(ScriptableRenderContext context,ref RenderingData renderingData)
    {
            //层级过滤,绘制Mask
            var draw = CreateDrawingSettings(shaderTag, ref renderingData, renderingData.cameraData.defaultOpaqueSortFlags);
            draw.overrideMaterial = settings.reflectionMaterial;
            draw.overrideMaterialPassIndex = 3;
            context.DrawRenderers(renderingData.cullResults, ref draw, ref filter);


            var drawDepth = CreateDrawingSettings(shaderTag, ref renderingData, renderingData.cameraData.defaultOpaqueSortFlags);
            drawDepth.overrideMaterial = settings.reflectionMaterial;
            drawDepth.overrideMaterialPassIndex = 2;
            context.DrawRenderers(renderingData.cullResults, ref drawDepth, ref filterDepth);



            CommandBuffer cmd = CommandBufferPool.Get("ReflectPass");

            RenderTextureDescriptor opaqueDescriptor = renderingData.cameraData.cameraTargetDescriptor;
            opaqueDescriptor.depthBufferBits = 0;


            //这里将原图像copy到sourceID中，后面做叠加使用
            int SourID = Shader.PropertyToID("_SourTex");
            cmd.GetTemporaryRT(SourID, opaqueDescriptor);
            cmd.CopyTexture(source, SourID);


            if (destination == RenderTargetHandle.CameraTarget)
            {

                // cmd.GetTemporaryRT(ReflectID.id, opaqueDescriptor, FilterMode.Point);

                cmd.GetTemporaryRT(BlurID.id, opaqueDescriptor, FilterMode.Point);
                cmd.GetTemporaryRT(ReflectID.id, opaqueDescriptor, FilterMode.Point);

                Blit(cmd, source, ReflectID.id, reflectionMaterial, 0);

                Blit(cmd, ReflectID.id, BlurID.id, reflectionMaterial, 1);
                Blit(cmd, BlurID.id, ReflectID.id);
                Blit(cmd, ReflectID.id, source, reflectionMaterial, 4);


            }
            else Blit(cmd, source, destination.Identifier());


            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void FrameCleanup(CommandBuffer cmd)
        {

            if (destination == RenderTargetHandle.CameraTarget)
                // cmd.ReleaseTemporaryRT(MixID.id);
            cmd.ReleaseTemporaryRT(BlurID.id);
            cmd.ReleaseTemporaryRT(ReflectID.id);
            cmd.ReleaseTemporaryRT(SourID.id);
            cmd.ReleaseTemporaryRT(MainTexID.id);
            cmd.ReleaseTemporaryRT(MaskID.id);
        }

    }


    [System.Serializable]
    public class ReflectionSettings {

        public Material reflectionMaterial = null;
        public LayerMask Reflection;
        public LayerMask Depth;
        [Range(1000, 5000)] public int QueueMin = 2000;
        [Range(1000, 5000)] public int QueueMax = 2500;
    }

    public ReflectionSettings settings = new ReflectionSettings();
    ReflectionPass reflectionPass;
    RenderTargetHandle reflectTexture;
    public override void Create()
    {
        reflectionPass = new ReflectionPass(settings, settings.reflectionMaterial);
        reflectionPass.renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
        reflectTexture.Init("_MainTex");
    }

    // Here you can inject one or multiple render passes in the renderer.
    // This method is called when setting up the renderer once per-camera.
    public override void AddRenderPasses(ScriptableRenderer renderer,ref RenderingData renderingData)
    {
        if (settings.reflectionMaterial == null)
        {
            Debug.LogWarningFormat("Missing Outline Material");
            return;
        }
        reflectionPass.Setup(renderer.cameraColorTarget, RenderTargetHandle.CameraTarget);
        renderer.EnqueuePass(reflectionPass);
    }
}







