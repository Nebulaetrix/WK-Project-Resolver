Shader "Dark Machine/SHDR_Base"
{
    /* ---------- Properties block unchanged ---------- */
    Properties
    {
        // Texture
        _MainTex ("Texture", 2D) = "white" {}
        // Tint
		_Color ("Color", Color) = (1,1,1,1)

        // Emission
		_Emission ("Emission", 2D) = "black" {}
		_EmissionMultiplier ("Emissivity Multiplier", Range (0, 8)) = 1.0
		_EmissionColor ("Emissivity Color", Color) = (1,1,1,1)
		_EmissiveIgnoreLightmap ("Emissive Ignore Lightmap", Range (0, 1)) = 0.0

        _IgnoreFog ("Ignore Fog", Range (0, 1)) = 0
        _Shading ("Shading", Range (0, 1)) = 0.9

		_Wiggle ("Wiggle", float) = 0.0
		_WiggleFreq ("WiggleFreq", float) = 2.0
		_WiggleSpeed ("WiggleSpeed", float) = 5.0
		_WorldWiggleModifier ("World Wiggle Mod", float) = 1.0

        // This is actually the shimmer texture. I want to change the name but it would break existing materials, so here we are. *sigh*
        // never make games kids.
        _Noise ("Noise", 2D) = "white" {}
        // Shimmer Amount
		_Shimmer ("Shimmer", float) = 0.0
		_ShimmerSpeed ("Shimmer Speed", Range (0, 5)) = 1.0
		_ShimmerFrequency ("Shimmer Frequency", Range (0, 5)) = 1.0
		_ShimmerOffset ("Shimmer Offset", Range (-1, 5)) = 0.0
		_ShimmerColor ("Shimmer Color", Color) = (1,1,1,1)
		_ShimmerOver ("ShimmerOver", float) = 0.0
		_ShimmerTextureMix ("ShimmerTextureMix", float) = 1.0
		
        // Post-process
		_Bright ("Bright", Range (-1, 4)) = 0.0

		_ROUNDMULT ("Round Multiplier", float) = 1.0

		_DitherAmount ("Dither Amount", Range (0, 1)) = 0.2

		_ScrollX ("ScrollX", Range (-5, 5)) = 0.0
		_ScrollY ("ScrollY", Range (-5, 5)) = 0.0

        // Corruption
		_CorruptDistance ("CorruptDistanceScale", Range (0, 5)) = 1.0
    }

    SubShader
    {
        Tags { "Queue"="AlphaTest" "RenderType"="Opaque" "IgnoreProjector"="True" }
        LOD 100
        Cull Back
        AlphaTest Greater 0.2

        Pass
        {
            CGPROGRAM
            #pragma target 3.0
            #pragma vertex   vert
            #pragma fragment frag
            #pragma multi_compile __ LIGHTMAP_ON

            #include "UnityCG.cginc"
            #include "DarkMachine.cginc"

            /* ---------- structures ---------- */
            struct appdata
            {
                float4 vertex : POSITION;
                float4 normal : NORMAL;
                fixed4 color  : COLOR;
                float2 uv     : TEXCOORD0;
                float2 uv2    : TEXCOORD1;
            };

            struct v2f
            {
                float2 uv      : TEXCOORD0;
                float2 uvLM    : TEXCOORD1;
                fixed4 color   : COLOR0;

                float4 pos     : SV_POSITION;
                half   camDist : TEXCOORD2;
                half2  shimmerSeed : TEXCOORD3;

                float3 worldPos  : TEXCOORD4;
                float4 screenPos : TEXCOORD5;
                half3  nrm       : TEXCOORD6;

				float3 vertex : VERTEXPOS;
            };

            /* ---------- uniforms ---------- */
            sampler2D _MainTex;        float4 _MainTex_ST;
            sampler2D _Emission;       float4 _Emission_ST;
            sampler2D _Noise;          float4 _Noise_ST;

            float4 _Color;
            half   _EmissionMultiplier;
            float4 _EmissionColor;
            float _EmissiveIgnoreLightmap;

            half _Shading, _Bright;
            half _ScrollX, _ScrollY;
            half _Wiggle, _WiggleFreq, _WiggleSpeed, _WorldWiggleModifier;
            half _Shimmer, _ShimmerFrequency, _ShimmerSpeed, _ShimmerOffset;
            half4 _ShimmerColor;
            half _ShimmerOver, _ShimmerTextureMix;
            half _DitherAmount;
            half _CorruptDistance;

            float _IgnoreFog;

            /* ---------- vertex ---------- */
            v2f vert (appdata v)
            {
                v2f o;

                float t = _Time;

                // Wiggle and World Wiggle. Vertex jitter without the rounding.
				float3 wiggle = _Wiggle * sin(_Time * _WiggleSpeed + cos(v.vertex.x * _WiggleFreq * 2) + sin(v.vertex.y * _WiggleFreq) + sin(v.vertex.z * _WiggleFreq *2));
				float3 worldWiggle = _WORLDWIGGLE.x * sin(_Time * _WORLDWIGGLE.z + cos(v.vertex.x * _WORLDWIGGLE.y * 2) + sin(v.vertex.y * _WORLDWIGGLE.y) + sin(v.vertex.z * _WORLDWIGGLE.y *2));
				worldWiggle *= _WorldWiggleModifier;
                
                // World position of the vertex, used for distance-based effects and as a base for the clip position. The actual clip position is calculated after the world position is warped, so that the warping doesn't affect distance-based effects or cause jittering.
                float3 wPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                // Apply the wiggle to the worldpos, for the vertex jitter. wiggle wiggle wiggle
                wPos += wiggle + worldWiggle;

                // Distance from camera, used for effects like dithering and corruption. Calculated before warping, so that the warping doesn't cause jittering or affect distance-based effects.
                float3 distError = _WorldSpaceCameraPos - wPos;

                float camDist = length(distError);

                // World warp is a more distant effect that offsets our positions here. Used for funny things like the pipeworks 'heat/breath' effect, and for the Ladder's wobble.
				wPos = WarpWorld(float4(wPos, 1), camDist).xyz;


                float4 clipPos = UnityWorldToClipPos(float4(wPos,1));
				
                o.camDist = camDist;

				float4 objectVert = mul(unity_WorldToObject, wPos);

				o.vertex = UnityObjectToClipPos(objectVert + wiggle + worldWiggle);

				float r = _ROUND * _ROUNDMULT;
				clipPos.xy = lerp(clipPos.xy, round(clipPos.xy * r) / r, _USEJITTER);
                // #endif

                o.pos       = clipPos;
                o.screenPos = ComputeScreenPos(clipPos);

                /* varyings */
                o.worldPos  = wPos;
                o.nrm       = UnityObjectToWorldNormal(v.normal);
                o.uv        = TRANSFORM_TEX(v.uv, _MainTex);
                o.uvLM      = v.uv2 * unity_LightmapST.xy + unity_LightmapST.zw;
                o.color     = v.color;

                return o;
            }

            /* ---------- fragment ---------- */
            fixed4 frag (v2f i) : SV_Target
            {
                float2 uv = i.uv + float2(_ScrollX, _ScrollY) * _Time.x;

                fixed4 col = tex2D(_MainTex, uv);
                col.rgb *=  i.color;
                clip(col.a - 0.99);

                fixed3 emission = tex2D(_Emission,
                                        uv * _Emission_ST.xy).rgb *
                                  (_EmissionMultiplier * _EmissionColor.rgb);

                /* lighting block ------------------------------------------------------- */
                lightinput lin;
                lin.vertex     = i.pos;
                lin.nrm        = float4(i.nrm,0);
                lin.vPos       = i.worldPos;
                lin.shading    = _Shading;
                lin.shimmer    = 0;
                lin.lightCount = 32;

                lighting L     = Light(lin);
                // lighting end.

                // Shimmer control.
				float shimmerBase = clamp(((sin((i.pos.y + i.pos.x + i.pos.z)  * .01 * _ShimmerFrequency + _Time.x * 100 * _ShimmerSpeed)+_ShimmerOffset) * 0.5 + 0.1), 0, 1) * _Shimmer;
                shimmerBase = max(shimmerBase, 0);
                half4 shimmerNoise = tex2D(_Noise, uv * _Noise_ST.xy);
                half4 shimmer      = shimmerBase * shimmerNoise * 2;
                
                // Shimmer override, adds an extra layer of shimmer which ignores any lighting conditions.
				float4 shimmerOver = clamp(lerp(_ShimmerColor,col, _ShimmerTextureMix) * (1 + (shimmerBase * _ShimmerColor) * _ShimmerOver * 5),0,3);

                col.rgb = max(col, shimmerOver);

                // Lighting combine.
                fixed3 lightingCol = (L.lights + shimmer * _ShimmerColor.rgb) *
                                     L.lightCol;

                // If this is lightmapped, 
                #ifdef LIGHTMAP_ON
                    half3 lm = DecodeLightmap(UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uvLM));
                    lightingCol = max(_FULLBRIGHT, lightingCol);
                    half3 worldBright = _WORLDBRIGHT * lm;
                    lm = max(_FULLBRIGHT, lm);

                    half3 lm2 =lerp(1, lightingCol, _LIGHTMAPMULT) * max(lm, min(L.bypassLightmap,100)*L.lightCol);
                    
                    lm2 = max(lm2, worldBright * _BRIGHTCOL);
                    col.rgb *= lm2;
                    col.rgb = clamp(col.rgb, 0, 4);
                    emission *= lerp(1, lightingCol, _LIGHTMAPMULT * (1-_EmissiveIgnoreLightmap)) * i.color.rgb;
                #else //if not lightmapped.
                    col.rgb *= lightingCol + _ENTITYBRIGHT * _BRIGHTCOL + _Bright;
                #endif

                /* corruption ---------------------------------------------------------- */
                float3 blend = saturate((abs(i.nrm) - 0.2) * 0.7);
                blend /= dot(blend,1);

                float3 cPos = i.worldPos;
                float  t    = _Time.x;
                
                // Corruption effect warp.
                float warp  = 3.3, wSz = 0.2, wSpd = 40;
                float3 angles = (t*wSpd +
                                 float3(cPos.y+cPos.z,
                                        cPos.x+cPos.z,
                                        cPos.x+cPos.y) * warp) * wSz;

                float3 sines  = sin(angles) * sin(warp);
                cPos += sines;

                float drift = 1.6;

                //Triplanar corruption mapping.
                float4 cX = tex2D(_CORRUPTTEXTURE, cPos.yz*0.23 - t*drift);
                float4 cY = tex2D(_CORRUPTTEXTURE, cPos.xz*0.23 - t*drift);
                float4 cZ = tex2D(_CORRUPTTEXTURE, cPos.xy*0.23 - t*drift);
                fixed4 corrupt = cX*blend.x + cY*blend.y + cZ*blend.z;

                half corruptAmount = (_CORRUPTHEIGHT - i.worldPos.y + 4) *
                                     0.2h * _CorruptDistance;
                                     
                col.rgb = lerp(col.rgb, corrupt.rgb, saturate(corruptAmount));
                /* corruption end -------------------------------------------------------- */



                /* dither + posterise ---------------------------------------------------- */
                half dither = ScreenspaceDither(i.screenPos);
                col.rgb = lerp(col.rgb, col.rgb * dither, _DitherAmount);

                half roundLvl = max(_DITHERLEVELS - i.camDist * 0.9h,
                                    _DITHERMINIMUM);

                if (_DITHEREFFECT == 0) roundLvl *= 16;

                //Convert to HSV then desaturate.
				float3 hsv = RGBtoHSV(col.rgb);

				hsv.b = round(hsv.b * roundLvl) / roundLvl;
	
				col.rgb = HSVtoRGB(hsv);
                /* end ---------------------------------------------------- */

                /* tint / fog / gamma ---------------------------------------------------- */
                col.rgb *= _Color;

                // funny emissive.
                half3 emissiveColor = emission.rgb * i.color.rgb;
                col.rgb += emissiveColor * 3;

                // world tint.
                col.rgb *= _WORLDTINT;
                    
                // Calculating this in fragment space so it doesn't cause issues with some larger surfaces.
                float3 distError = _WorldSpaceCameraPos - i.worldPos;
                float camDist = length(distError);
                    
                //Clamp to prevent negative colors.
                col.rgb  = max(col.rgb, 0);

                //Fog
                col.rgb = lerp(CalculateFog(col, camDist, dither, i.worldPos), col.rgb, _IgnoreFog);

                // We want to add a tiny bit of emissive in after the fog calc, so emissivem materials shine through the fog.
                col.rgb += emissiveColor * 0.02;

                // Final clamp and return.
                col.rgb += (_OFFSET * 4 * col.rgb);

                // Last but not least, set the world min so we can have nice dark color control.
                col.rgb  = max(col.rgb, _WORLDMIN);

                return col;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
