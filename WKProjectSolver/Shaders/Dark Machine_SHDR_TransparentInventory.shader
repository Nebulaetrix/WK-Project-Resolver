Shader "Dark Machine/Transparent Inventory"
{
    Properties {
        _Color ("Main Color", Color) = (1,1,1,1)
        _MainTex ("Base (RGB) Trans (A)", 2D) = "white" {}


		_Wiggle ("Wiggle", float) = 0.0
		_WiggleFreq ("WiggleFre", float) = 2.0
		_WiggleSpeed ("WiggleSpeed", float) = 5.0
    }

    SubShader {
        Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent" "IgnoreProjector"="True"}

        LOD 100
		Cull Off
		ZWrite Off

        Lighting Off
        Fog { Mode Off }

        Blend SrcAlpha OneMinusSrcAlpha 
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                fixed4 color : COLOR;

            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float3 worldPos : WORLDPOSITION;
                float camDistance : DISTANCE;
                fixed4 color : COLOR;
            };

            float4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST;

            float _Wiggle;
			float _WiggleFreq;
			float _WiggleSpeed;


            v2f vert (appdata v)
            {
                v2f o;

				float3 wiggle = _Wiggle * sin(_Time * _WiggleSpeed + cos(v.vertex.x * _WiggleFreq * 2) + sin(v.vertex.y * _WiggleFreq) + sin(v.vertex.z * _WiggleFreq *2));
				o.vertex = UnityObjectToClipPos(v.vertex + wiggle);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.color = v.color;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                
                float3 cameraPos = _WorldSpaceCameraPos;
                o.camDistance = distance(cameraPos, o.worldPos);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv) * i.color;
                return col;
            }
            ENDCG
        }
    }
}
