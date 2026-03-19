Shader "Dark Machine/SHDR_WaterShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Mask ("Mask", 2D) = "white" {}

        _Color ("Color", Color) = (1,1,1,1)
        _EdgeColor ("Edge Color", Color) = (1,1,1,1)
        _EdgeFade ("Edge Fade", float) = 0.0
        _EdgeMult ("Edge Mult", float) = 1.0

        _Depth ("Depth", float) = 0.0
        _DepthColor ("Depth Color", Color) = (1,1,1,1)


        _Fade ("Fade", float) = 0.0

		_ScrollX ("ScrollX", Range (-20, 20)) = 0.0
		_ScrollY ("ScrollY", Range (-20, 40)) = 0.0

        _OverlayTexture ("Overlay Texture", 2D) = "white" {}
        _OverlayOpacity ("Overlay Opacity", float) = 0.0


        _Wiggle ("Wiggle", float) = 0.0
		_WiggleFreq ("WiggleFreq", float) = 2.0
		_WiggleSpeed ("WiggleSpeed", float) = 5.0
		_WorldWiggleModifier ("World Wiggle Mod", float) = 1.0

        _ROUNDMULT ("Round Multiplier", float) = 1.0
        
        _DitherAmount ("Dither Amount", Range (0, 1)) = 0.2

        _Bright ("Brightness", Range (0, 5)) = 1
        _FogMult ("FogMult", Range (0, 5)) = 1

        _AlphaMult ("Alpha Multiplier", Range (0, 1)) = 1


    }
    SubShader//
    {
        Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha
        Cull off 
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
                float4 normal : NORMAL;
                float3 viewDir : VIEWDIR;
                float3 viewNormal : VIEWNORMAL;
                fixed4 color : COLOR;

                float3 objectNormal : OBJECTNORMAL;
                float4 objectVertex : OBJECTVERTEX;

                float3 worldPos : WORLDPOSITION;

                float4 projPos : PROJECTIONPOSITION;
                // float3 screenUV : SCREENUV;

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

            sampler2D _OverlayTexture;
            float4 _OverlayTexture_ST;
            float _OverlayOpacity;

            float4 _EdgeColor;
            float _EdgeFade;
            float _EdgeMult;

            float4 _DepthColor;

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

                o.projPos = float4(0, 0, 0, 0);
                COMPUTE_EYEDEPTH(o.projPos.z);

				float3 wiggle = _Wiggle * sin(_Time * _WiggleSpeed + cos(v.vertex.x * _WiggleFreq * 2) + sin(v.vertex.y * _WiggleFreq) + sin(v.vertex.z * _WiggleFreq *2));
				//float3 worldWiggle = _WORLDWIGGLE.x * sin(_Time * _WORLDWIGGLE.z + cos(v.vertex.x * _WORLDWIGGLE.y * 2) + sin(v.vertex.y * _WORLDWIGGLE.y) + sin(v.vertex.z * _WORLDWIGGLE.y *2));
				//worldWiggle *= _WorldWiggleModifier;


				o.vertex = UnityObjectToClipPos(v.vertex + wiggle);

				o.vertex.xy = round(o.vertex.xy * r) / r;


                //o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.maskUV = TRANSFORM_TEX(v.uv, _Mask);

                o.normal.xyz = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                // float3 worldNormal = UnityObjectToWorldNormal(v.normal);
                o.color = v.color;

                o.viewDir.xyz = mul((float3x3)unity_CameraToWorld, float3(0,0,1));
                // o.viewNormal = mul((float3x3)UNITY_MATRIX_V, worldNormal);

				o.color = v.color;

                o.screenPos = ComputeScreenPos(o.vertex);
                // o.screenPos = ComputeScreenPos(o.vertex);
                COMPUTE_EYEDEPTH(o.screenPos.z);

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float2 driftUV = i.uv;
                driftUV.x += _ScrollX * _Time.x;
                driftUV.y += _ScrollY * _Time.x;

                // sample the texture
                fixed4 col = _Color * tex2D(_MainTex, driftUV);
                // Linear01Depth(
                float depth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.screenPos)));

                // depth = saturate(abs(depth - i.projPos.z) * _Depth);
                // float depth = tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(i.screenPos)).r;
                // depth = depth - i.screenPos.z
                float depthDifferent = (depth - i.screenPos.z) * _Depth * 10;

                depthDifferent = abs(depthDifferent);

                float fade = depthDifferent;

                depthDifferent = clamp(depthDifferent, 0, 1);


                fade = clamp(fade, 0,1);
                
                // float closeFade = clamp(1-i.vertex.z*8, 0, 1);

                // closeFade *= abs(dot(i.viewDir, i.normal)-0.5);
                //fade += ((1-i.vertex.z) * 3, fade);


                
                float3 worldNorm = UnityObjectToWorldNormal(i.objectNormal);
                //float3 viewNorm = mul(UNITY_MATRIX_MV, i.objectNormal);


                // get view space position of vertex
                //float3 viewPos = mul(UNITY_MATRIX_MV, i.objectVertex);//UnityObjectToViewPos(i.objectVertex);

                float3 worldPos = mul(unity_ObjectToWorld, i.objectVertex);

                float dist = distance(worldPos, _WorldSpaceCameraPos);

                // float3 viewDir = normalize(viewPos);

                // get vector perpendicular to both view direction and view normal
                // float3 viewCross = cross(viewDir, viewNorm);
                
                // swizzle perpendicular vector components to create a new perspective corrected view normal
                //viewNorm = 1-dot(viewNorm, -viewDir);//float3(-viewCross.y, viewCross.x, dot(viewNorm, -viewDir));
                // Calculate the view direction in view space
                //o.viewDir.xy = viewNorm;//viewDir.xy * 0.5 + 0.5;

                //col.a = min(fade, closeFade);
                float planeFade = clamp(abs(dot(worldNorm, _WorldSpaceCameraPos	- worldPos) / _Fade ) - 0.1, 0, 1);
                
                float screenspaceDither = (ScreenspaceDither(i.screenPos));

                float dithered = screenspaceDither;

                col.rgb = HSVPosterize(lerp(col.rgb, dithered, 0.01 * _DitherAmount), _DITHERLEVELS * 3);

                dithered = ((clamp((fade),0,1) * planeFade) * 10) - dithered * 0.1;
                dithered = PosterizeValue(dithered, _DITHERLEVELS);

                //col.rgb = ;//vdir;//absds(viewNorm / 20);

                float alpha = col.a;
                alpha *= dithered;

                // col.a *= dithered; //1-clamp(depth, 0, 1)) * planeFade;
                
                
                alpha = min(alpha, _Color.a);

                float edge = depthDifferent;//lerp(i.vertex.z,depth, clamp(sin(driftUV.x * 25 + _Time.x),0,1)) * 10;
                //col.a = 1;
                edge = step(edge, _EdgeFade +  max(max(col.r, col.g), col.b) * _EdgeMult);



                col.rgb = lerp(col.rgb, _EdgeColor, edge);// * (1-clamp(dist / (20),0,1))
                

                //col.rgb = dithered * 10;


                //Debug
                //col.rgb = lerp(dithered, 0, clamp(sin(driftUV.x * 30 + _Time.x),0,1));
                //col.a = 1;

                // alpha *= i.color.rgb * i.color.a;
                
                alpha += edge * 0.3;//max(alpha, edge * _EdgeColor.a);


                col.a = lerp(alpha, 1, _DepthColor.a);
                col.a *= tex2D(_Mask, i.maskUV).r;

                
                // col.a = alpha;
                col.rgb = lerp(_DepthColor + col.rgb, col.rgb, 1-(depthDifferent * (_DepthColor.a)));

                // Overlay
                float4 overlayCol = tex2D(_OverlayTexture, TRANSFORM_TEX(i.uv, _OverlayTexture));
                col.rgb = lerp(col.rgb, overlayCol.rgb, _OverlayOpacity * overlayCol.a);
                
                col.rgb *= _Bright;

                lightinput lin;
				lin.vertex = i.vertex;
				lin.nrm = i.normal;
				lin.vPos = i.worldPos;
				lin.shading = 1;
				lin.shimmer = 0;
                lin.lightCount = 16;

                lighting l = Light(lin);
                
                float3 lights = l.lights * l.lightCol;

                col.rgb *= lights + _WORLDBRIGHT;
                col.rgb *= _WORLDTINT;



                //Fog
                
                col.a *= _AlphaMult;

                col = clamp(col, 0, 1);

                col.a *= planeFade;
                col.a = lerp(col.a, _EdgeColor.a, edge);

                // alpha *= i.color.rgb * i.color.a;
                col.a *= i.color.rgb * i.color.a;


                col.rgb = CalculateFog(col, dist, screenspaceDither, i.worldPos);
                col.rgb  = max(col.rgb, _WORLDMIN);
                
                // col *= _GAMMA;

                // col = clamp(dist * 0.01, 0, 1);
                //col.a = 0;
                return col;
            }
            ENDCG
        }
    }
}
