Shader "Dark Machine/SHDR_Base_Inventory"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1, 1, 1, 1)

        _IgnoreWorld ("Ignore World", Range (0, 1)) = 0.0
        
        [NoScaleOffset]
        _PaletteBase ("Base Palette", 2D) = "white" {}
		_PaletteBaseBlend ("Base Palette Blend", Range (0, 1)) = 0.0

        _ColorMask ("Color Mask", 2D) = "white" {}

        [Header(Overlay Settings)] [Space(10)]
        _OverlayMult ("Overlay - Multiply", 2D) = "white" {}
        _OverlayMultAmount ("Overlay - Multiply Amount", Range (0, 1)) = 0.0
        _OverlayAdd ("Overlay - Add", 2D) = "black" {}
        _OverlayAddAmount ("Overlay - Add Amount", Range (0, 1)) = 0.0

		[Header(Layer Settings)] [Space(10)]
        _LayerOver ("Layer - Over", 2D) = "black" {}
        _LayerUnder ("Layer - Under", 2D) = "black" {}

        [NoScaleOffset]
        _PaletteLayers ("Layers Palette", 2D) = "white" {}

		[Header(Wiggle Settings)] [Space(10)]
		
        _Wiggle ("Wiggle", float) = 0.0
        _WiggleFreq ("WiggleFreq", float) = 2.0
        _WiggleSpeed ("WiggleSpeed", float) = 5.0
        _WorldWigglaseodifier ("World Wiggle Mod", float) = 1.0

		[Header(Shimmer Settings)] [Space(10)]
		_Noise ("Shimmer Mask", 2D) = "white" {}
        _Shimmer ("Shimmer", float) = 0.0
        _ShimmerSpeed ("Shimmer Speed", Range (0, 5)) = 1.0
        _ShimmerFrequency ("Shimmer Frequency", Range (0, 5)) = 1.0
        _ShimmerOffset ("Shimmer Offset", Range (0, 5)) = 0.0
        _ShimmerColor ("Shimmer Color", Color) = (1, 1, 1, 1)


        [NoScaleOffset][Header(Dither Settings)] [Space(10)]

        _DitherTex ("Dither", 2D) = "white" {}
        _DitherAmount ("Dither Amount", Range (0, 1)) = 0.2
        _DitherScale ("Dither Scale", Range (0, 5)) = 1
        _PosterizationScalar ("Posterization", Range (0, 5)) = 1

		[Header(Scroll Settings)] [Space(10)]
        _ScrollX ("ScrollX", Range (-2, 2)) = 0.0
        _ScrollY ("ScrollY", Range (-2, 2)) = 0.0

		[Header(Lighting And Brightness)] [Space(10)]
        _Shading ("Shading", Range (0, 1)) = 0.9
        _Emissive ("Emissive", Range (0, 10)) = 0
        _Brightness ("Brightness", float) = 0
        _Invert ("Invert", Range (0, 1)) = 0

		[Header(Transformations)] [Space(10)]
        _OverlayRect ("Overlay Rect", Vector) = (0, 0, 1, 1)
        _Transformation ("Transformation", Vector) = (0, 0, 1, 0)
		_ROUNDMULT ("Round Multiplier", float) = 1.0
    }


    SubShader
    {
        Tags { "Queue" = "Transparent" "RenderType" = "Transparent" "IgnoreProjector" = "True" "DisableBatching" = "True" }

        Pass
        {

            Tags { "Queue" = "Transparent" "RenderType" = "Transparent" "IgnoreProjector" = "True" "DisableBatching" = "True" }
            LOD 100
            Blend SrcAlpha OneMinusSrcAlpha
            Cull Off
            ZWrite Off

            // Offset -1, -1

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_instancing

            #include "UnityCG.cginc"
            #include "DarkMachine.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float4 normal : NORMAL;
                fixed4 color : COLOR; // apparently must be fixed4 to work with instancing
                float2 uv : TEXCOORD0;
                float2 texcoord1 : TEXCOORD1;
                float4 col : COLOR;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float2 uv1 : TEXCOORD1;

                float4 vertex : SV_POSITION;
                float3 vPos : NORMAL;
                float4 nrm : TANGENT;
                fixed4 color : COLOR;

                float3 worldPos : WORLDPOSITION;
                float4 screenPos : SCREENUV;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            float4 _Color;
            sampler2D _ColorMask;

            sampler2D _PaletteBase;
			float4 _PaletteBase_TexelSize;
            sampler2D _PaletteLayers;
			float _PaletteBaseBlend;


            sampler2D _OverlayMult;
            float4 _OverlayMult_ST;
            float _OverlayMultAmount;

            sampler2D _OverlayAdd;
            float4 _OverlayAdd_ST;
            float _OverlayAddAmount;

            sampler2D _LayerOver;
            float4 _LayerOver_ST;

            sampler2D _LayerUnder;
            float4 _LayerUnder_ST;

            sampler2D _Noise;
            float4 _Noise_ST;

            float _Shading;

            float _ScrollX;
            float _ScrollY;

            float _Wiggle;
            float _WiggleFreq;
            float _WiggleSpeed;

            float _Shimmer;
            float _ShimmerFrequency;
            float _ShimmerSpeed;
            float _ShimmerOffset;
            float4 _ShimmerColor;

            float _Invert;
            float _Brightness;

            float4 _Transformation;

            float _WorldWiggleModifier;
            float _CorruptAmount;

            float _Emissive;

            float4 _OverlayRect;

            float _IgnoreWorld;


            // uniform sampler2D _FOGOFWAR;
            // uniform float4 _FOGOFWAR_ST;



            sampler2D _DitherTex;
            float _DitherAmount;
            float _DitherScale;

            float _PosterizationScalar;

            float _FOWFade;

            float4 _DitherTex_TexelSize; // Contains texel size (1 / width, 1 / height, width, height)


            v2f vert (appdata v)
            {
                v2f o;

                //How much to round
                float r = _ROUND * _ROUNDMULT;

                float3 wiggle = _Wiggle * sin(_Time * _WiggleSpeed + cos(v.vertex.x * _WiggleFreq * 2) + sin(v.vertex.y * _WiggleFreq) + sin(v.vertex.z * _WiggleFreq * 2));
                float3 worldWiggle = _WORLDWIGGLE.x * sin(_Time * _WORLDWIGGLE.z + cos(v.vertex.x * _WORLDWIGGLE.y * 2) + sin(v.vertex.y * _WORLDWIGGLE.y) + sin(v.vertex.z * _WORLDWIGGLE.y * 2));
                worldWiggle *= _WorldWiggleModifier;

                // World - space position
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

                float3 objRight = float3(1, 0, 0);
                float3 objUp = float3(0, 1, 0);
                float3 objForward = float3(0, 0, 1);

                float3 objPos = v.vertex.xyz;



                objPos += objRight * _Transformation.x;
                objPos += objUp * _Transformation.y;

                objPos *= _Transformation.z;

                // Convert degrees to radians
                float angleRad = radians(_Transformation.w);
                objPos = RotateAroundAxis(objPos, float3(0, 0, 0), float3(0, 0, 1), angleRad);

                o.vertex = UnityObjectToClipPos(objPos + wiggle + worldWiggle);


                o.vertex.xy = round(o.vertex.xy * r) / r;


                o.screenPos = ComputeScreenPos(o.vertex); //screenPos.xy / screenPos.xy;

                o.vPos = mul(unity_ObjectToWorld, v.vertex).xyz;


                o.worldPos = worldPos;

                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.color = v.color;

                o.nrm.xyz = UnityObjectToWorldNormal(v.normal);

                o.uv1 = v.texcoord1; //TRANSFORM_TEX(v.texcoord1, _MainTex);

                //UNITY_TRANSFER_FOG(o, o.vertex);

                //o.vPos.y += sin(o.vertex.z * 20) * 10;

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                i.uv.x += (_ScrollX * _Time.x);
                i.uv.y += (_ScrollY * _Time.x);

                //float4 test = 1;
                //test.xyz = i.vPos - fmod(i.uv.xyx * _TexSize, 1) / (_TexSize / 8);



                //noise = tex2D(_Noise, pos.xz * 0.6 + pos.y * 0.6) - 0.1;
                //moving noise.

                fixed4 col = tex2D(_MainTex, i.uv);
				// _PaletteBase_TexelSize.z
				col.rgb = lerp(col.rgb, tex2D(_PaletteBase, float2((col.r * 255 + 1) / _PaletteBase_TexelSize.z, 0.5)), _PaletteBaseBlend);

                col.rgb += _Brightness;
                col.rgb = lerp(col.rgb, 1 - col.rgb, _Invert);

                //Overlay
                float2 overlayUV = i.uv;
                overlayUV.x -= _OverlayRect.x;
                overlayUV.y -= _OverlayRect.y;
                overlayUV.x /= _OverlayRect.z;
                overlayUV.y /= _OverlayRect.w;

                float4 overlayMult = tex2D(_OverlayMult, (overlayUV + _OverlayMult_ST.zw) * _OverlayMult_ST.xy);
                float overlayMix = _OverlayMultAmount - (1 - overlayMult.a);

                if(overlayMult.a <= 0) overlayMult.rgb = 1;

                col.rgb = lerp(col.rgb, col.rgb * overlayMult.rgb, overlayMix);

                //Layer Over and Under
                fixed4 layerOver = tex2D(_LayerOver, (overlayUV + _LayerOver_ST.zw) * _LayerOver_ST.xy);
                fixed4 layerUnder = tex2D(_LayerUnder, (overlayUV + _LayerUnder_ST.zw) * _LayerUnder_ST.xy);

                col = lerp(col, layerOver, layerOver.a);

                col = lerp(layerUnder, col, col.a);

                float4 baseCol = col;

                // float overAlpha = max(layerOver.a, col.a);
                // overAlpha = max(layerUnder.a, overAlpha);
                // col.a = overAlpha;

                //Lighting
                lightinput lin;
                lin.vertex = i.vertex;
                lin.nrm = i.nrm;
                lin.vPos = i.vPos;
                lin.shading = _Shading;
                lin.shimmer = 0;

                lighting l = Light(lin);



                //Shimmer
                float shimmer = clamp(((sin((i.vertex.y + i.vertex.x + i.vertex.z) * .01 * _ShimmerFrequency + _Time.x * 100 * _ShimmerSpeed) + _ShimmerOffset) * 0.5 + 0.1), 0, 1) * _Shimmer * tex2D(_Noise, i.uv * _Noise_ST.xy) * 2;

                float3 lights = (clamp(l.lights, 0, 1) + shimmer * _ShimmerColor) * clamp(l.lightCol, 0, 1.5);

                col.rgb *= lights + _ENTITYBRIGHT * _BRIGHTCOL + _Emissive;

                col = lerp(col, baseCol, _IgnoreWorld);

                baseCol = col;

                // clip(col.a - 0.01);

                // Get the world position of the camera
                float3 cameraPos = _WorldSpaceCameraPos;

                // Calculate the distance from the camera to the fragment
                float dist = distance(cameraPos, i.worldPos);

                // -- -- GENERAL EFFECTS -- --
                float2 screenPosition = i.screenPos.xy / i.screenPos.w;
                // Calculate screen - space UVs for the dither texture
                float2 ditherUV = (frac(screenPosition / _DitherTex_TexelSize.zw) * _ScreenParams.xy) / 2;

                // Sample the dither texture
                half4 screenspaceDither = tex2D(_DitherTex, ditherUV * _DitherScale);


                //General dither.
                col.rgb = lerp(col.rgb, col.rgb * screenspaceDither.r, _DitherAmount);

                //Convert to HSV then desaturate.
                float3 hsv = RGBtoHSV(col.rgb);

                //hsv.b *= (sin(_Time.y) * 0.05);

                int ditherLevels = ditherLevels;
                // float roundAmount = max(_DITHERLEVELS - (dist * 1.3), _DITHERMINIMUM) * _PosterizationScalar;

                float roundAmount = max(_DITHERLEVELS, _DITHERMINIMUM) * _PosterizationScalar;

                hsv.b = round(hsv.b * roundAmount) / roundAmount;

                col.rgb = HSVtoRGB(hsv);

                // col = max(col, _WORLDMIN); //WORLD MIN

                col *= _WORLDTINT; //WORLD TINT

                // -- -- - FOG -- -- --
                // float fogdist = dist * _FOG.w;
                // fogdist = fogdist - (screenspaceDither * _FOGDITHERAMOUNT);
                // //fogdist -= 0.1;

                // fogdist = max(round(fogdist * _FOGDITHERLEVELS) / _FOGDITHERLEVELS, fogdist);

                // fogdist = clamp(fogdist, 0, 1);
                // col.rgb = lerp(col.rgb, _FOG.rgb, (fogdist)); //FOG
                // -- - END FOG -- -

                col.a *= _Color.a;
                // baseCol.a *= _Color.a;

                float4 maskedColor = lerp(1, i.color, tex2D(_ColorMask, i.uv));
                maskedColor.a = 1;
                col.rgb = col * maskedColor * _Color;
                
                col.rgb = max(col.rgb, _WORLDMIN);

                col.rgb = lerp(col.rgb, col.rgb + tex2D(_OverlayAdd, (i.uv + _OverlayAdd_ST.zw) * _OverlayAdd_ST.xy), _OverlayAddAmount);

                baseCol.a = col.a;

                
                col.a *= i.color.a;

                // col.a *= 0.5;
                // col *= _GAMMA;
                return col;
            }
            ENDCG
        }






    }
}
