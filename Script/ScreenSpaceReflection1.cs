using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class ScreenSpaceReflection:MonoBehaviour
{

    [SerializeField]
    Material reflectionMaterial = null;
    Camera currentCamera = null;
    private Texture2D ditherMap = null;

    private void Awake()
    {
        var shader = Shader.Find("MyURP/URPssr");
        reflectionMaterial = new Material(shader);
        currentCamera = GetComponent<Camera>();
        ditherMap = GenerateDitherMap();
        reflectionMaterial.SetTexture("_ditherMap", ditherMap);

    }
    private void OnEnable()
    {
        if (ditherMap == null)
            ditherMap = GenerateDitherMap();

    }




private Texture2D GenerateDitherMap()
{ 
    int texSize = 4;
    var ditherMap = new Texture2D(texSize, texSize, TextureFormat.Alpha8, false, true);
    ditherMap.filterMode = FilterMode.Point;
        Color32[] colors = new Color32[texSize * texSize];

        colors[0] = GetDitherColor(0.0f);
        colors[1] = GetDitherColor(8.0f);
        colors[2] = GetDitherColor(2.0f);
        colors[3] = GetDitherColor(10.0f);
        colors[4] = GetDitherColor(12.0f);
        colors[5] = GetDitherColor(4.0f);
        colors[6] = GetDitherColor(14.0f);
        colors[7] = GetDitherColor(6.0f);
        colors[8] = GetDitherColor(3.0f);
        colors[9] = GetDitherColor(11.0f);
        colors[10] = GetDitherColor(1.0f);
        colors[11] = GetDitherColor(9.0f);
        colors[12] = GetDitherColor(15.0f);
        colors[13] = GetDitherColor(7.0f);
        colors[14] = GetDitherColor(13.0f);
        colors[15] = GetDitherColor(5.0f);

        ditherMap.SetPixels32(colors);
        ditherMap.Apply();
        return ditherMap;

    }

private Color32 GetDitherColor(float value)
    {
        byte byteValue = (byte)(value / 16.0f * 255);
        return new Color32(byteValue, byteValue, byteValue, byteValue);
    }


}