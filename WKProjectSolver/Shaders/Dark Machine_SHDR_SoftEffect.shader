Shader "Dark Machine/SHDR_SoftEffect"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Mask ("Mask", 2D) = "white" {}

        _Color ("Color", Color) = (1,1,1,1)
        _EdgeColor ("Edge Color", Color) = (1,1,1,1)
        _EdgeFade ("Edge Fade", float) = 0.0

        _Depth ("Depth", float) = 0.0
        _Fade ("Fade", float) = 0.0

		_ScrollX ("ScrollX", Range (-10, 100)) = 0.0
		_ScrollY ("ScrollY", Range (-10, 10)) = 0.0

        _Wiggle ("Wiggle", float) = 0.0
		_WiggleFreq ("WiggleFreq", float) = 2.0
		_WiggleSpeed ("WiggleSpeed", float) = 5.0
		_WorldWiggleModifier ("World Wiggle Mod", float) = 1.0

        _ROUNDMULT ("Round Multiplier", float) = 1.0
        
        _DitherAmount ("Dither Amount", Range (0, 1)) = 0.2

        _Bright ("Brightness", Range (0, 200)) = 1
        _FogMult ("FogMult", Range (0, 20)) = 1
        _AlphaMult ("Alpha Multiplier", Range (0, 1)) = 1

    }
    SubShader
    {
        Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off 
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #include "DarkMachine.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 normal : NORMAL;
                float4 color : COLOR;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float2 maskUV : TEXCOORD1;


                float4 vertex : SV_POSITION;
                float4 screenPos : SCREENUV;
                float3 normal : NORMAL;
                float3 viewDir : VIEWDIR;
                float3 viewNormal : VIEWNORMAL;
                fixed4 color : COLOR;

                float3 objectNormal : OBJECTNORMAL;
                float4 objectVertex : OBJECTVERTEX;

            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            sampler2D _Mask;
            float4 _Mask_ST;

            float _ScrollX;
            float _ScrollY;

            float _Fade;
            float _Depth;

            float4 _Color;
			sampler2D _CameraDepthTexture;

            float4 _EdgeColor;
            float _EdgeFade;

			float _Wiggle;
			float _WiggleFreq;
			float _WiggleSpeed;

            float _DitherAmount;

            float _Bright;
            
            float _FogMult;

            float _AlphaMult;

            v2f vert (appdata v)
            {
                v2f o;

                float r = _ROUND * _ROUNDMULT;


                // Transform the normal to view space
                o.objectNormal = v.normal;
                o.objectVertex = v.vertex;

				float3 wiggle = _Wiggle * sin(_Time * _WiggleSpeed + cos(v.vertex.x * _WiggleFreq * 2) + sin(v.vertex.y * _WiggleFreq) + sin(v.vertex.z * _WiggleFreq *2));
				//float3 worldWiggle = _WORLDWIGGLE.x * sin(_Time * _WORLDWIGGLE.z + cos(v.vertex.x * _WORLDWIGGLE.y * 2) + sin(v.vertex.y * _WORLDWIGGLE.y) + sin(v.vertex.z * _WORLDWIGGLE.y *2));
				//worldWiggle *= _WorldWiggleModifier;


				o.vertex = UnityObjectToClipPos(v.vertex + wiggle);
				
				o.vertex.xy = round(o.vertex.xy * r) / r;


                //o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.maskUV = TRANSFORM_TEX(v.uv, _Mask);

                o.normal.xyz = UnityObjectToWorldNormal(v.normal);
                // float3 worldNormal = UnityObjectToWorldNormal(v.normal);
                o.color = v.color;

                o.viewDir.xyz = mul((float3x3)unity_CameraToWorld, float3(0,0,1));
                // o.viewNormal = mul((float3x3)UNITY_MATRIX_V, worldNormal);

				o.color = v.color;


                o.screenPos = ComputeScreenPos(o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float2 driftUV = i.uv;
                driftUV.x += _ScrollX * _Time.x;
                driftUV.y += _ScrollY * _Time.x;

                // sample the texture
                half4 col = _Color * tex2D(_MainTex, driftUV);

                half depth = tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(i.screenPos)).r * 1;

                half fade = (i.vertex.z - depth) * 10 * _Depth;


                fade = clamp(fade, 0,1);
                
                half3 worldNorm = UnityObjectToWorldNormal(i.objectNormal);

                half3 worldPos = mul(unity_ObjectToWorld, i.objectVertex);

                half dist = distance(worldPos, _WorldSpaceCameraPos);
                
                half planeFade = clamp(abs(dot(worldNorm, _WorldSpaceCameraPos	- worldPos) / _Fade ) - 0.1, 0, 1);
                
                half screenspaceDither = (ScreenspaceDither(i.screenPos));

                half dithered = screenspaceDither;
                
                half ditherLevels = _DITHERLEVELS;

                ditherLevels = lerp(ditherLevels * 16, ditherLevels, _DITHEREFFECT);

                col.rgb = HSVPosterize(lerp(col.rgb, dithered, 0.01 * _DitherAmount), ditherLevels * 3);

                dithered = ((clamp((fade),0,1) * planeFade) * 10) - dithered * 0.1 * _DitherAmount;
                dithered = PosterizeValue(dithered, ditherLevels);

                col.a *= dithered;
                
                col.a *= tex2D(_Mask, i.maskUV);
                
                col.a = min(col.a, _Color.a);

                half edge = ((i.vertex.z-depth)*i.vertex.w) * 200;
                //col.a = 1;
                edge = step(edge, _EdgeFade + col.rgb * 10);


                col.rgb = lerp(col.rgb, _EdgeColor, edge * (1-clamp(dist / (20),0,1)));

                col.a *=  i.color.rgb * i.color.a;

                col.rgb *= i.color.rgb;

                col.rgb *= _Bright + (((_WORLDBRIGHT) * _BRIGHTCOL) * 0.2);

                //----- FOG ------
				// half fogdist = dist * _FOG.w * 0.1 * _FogMult;
				// fogdist = fogdist-(screenspaceDither * _FOGDITHERAMOUNT);

				// fogdist = max(round(fogdist*_FOGDITHERLEVELS)/_FOGDITHERLEVELS, fogdist);

				// fogdist = clamp(fogdist, 0, 1);
				// col.rgb = lerp(col.rgb, _FOG.rgb, (fogdist)); //FOG

                col.rgb = CalculateFog(col, dist * 0.1 * _FogMult, screenspaceDither, worldPos);
                col.a = CalculateFog(col.a, dist * 0.1 * _FogMult, screenspaceDither, worldPos).r;

				// --- END FOG ---

                col = max(col, 0);
                
                col.rgb *= _WORLDTINT;

                col = clamp(col, 0, 5);

                col.rgb  += (_OFFSET * 4 * col.r * 5);
                
                col.a *= _AlphaMult;

                return col;
            }
            ENDCG
        }
    }
}
