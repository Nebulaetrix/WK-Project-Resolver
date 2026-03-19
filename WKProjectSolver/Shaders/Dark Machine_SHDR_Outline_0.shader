Shader "Dark Machine/SHDR_Outline"
{
    Properties {
        _Color ("Main Color", Color) = (1,1,1,1)
        _Brightness ("Brightness", float) = 1.0

    }

    SubShader
    {
        Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
        
        ZWrite Off
        Lighting Off
        Fog { Mode Off }
        Cull back

        Blend SrcAlpha OneMinusSrcAlpha 

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float3 worldPos : WORLDPOSITION;
                float camDistance : DISTANCE;
            };

            float4 _Color;
            float _Brightness;
            float _OUTLINEBRIGHT = 1;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;

                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                
                float3 cameraPos = _WorldSpaceCameraPos;
                o.camDistance = distance(cameraPos, o.worldPos);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = _Color * (1-clamp(i.camDistance / 4, 0, 1));
                col.a *= sin(_Time.x * 80 + i.vertex.y * 0.01f);

                col.rgb = abs(col) *_Brightness * _OUTLINEBRIGHT;
                col.a = clamp(col.a, 0, 1);
                return col;
            }
            ENDCG
        }
    }
}
