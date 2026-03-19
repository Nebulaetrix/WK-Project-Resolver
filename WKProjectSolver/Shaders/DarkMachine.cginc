

#include "UnityCG.cginc"

struct vertinfo {
    float2 uv : TEXCOORD0;
    UNITY_FOG_COORDS(1)
    float4 vertex : SV_POSITION;
    float3 vPos : NORMAL;
    float4 nrm : TANGENT;
    fixed4 color : COLOR;

    float3 worldPos : WORLDPOSITION;
    float4 screenPos : SCREENUV;
    
};

struct lightinput {
    float4 vertex : SV_POSITION;
    float3 vPos : NORMAL;
    float4 nrm : TANGENT;
    float shading;
    float shimmer;
    int lightCount;
};

// ---------------------------------------------------------------------------
//  struct definition
// ---------------------------------------------------------------------------
struct lighting
{
    float  lights          : COLOR;   // single-channel brightness
    float4 lightCol        : COLOR;   // max-per-channel colour
    float  lightmapLights  : COLOR;   // scalar sent back to the surface
    float4 bypassLightmap;            // rgb → additive, a → unused
    float emissiveMult;
};

// struct lighting {
    // 	float lights : COLOR;
    // 	float4 lightCol : COLOR;
    //     float lightmapLights : COLOR;
    // 	float4 bypassLightmap;
// };

//Light Info
float _LIGHTMAPMULT;

//-- WORLD TINTING --
float4 _WORLDTINT;
float4 _WORLDMIN;

//-- FOG --
float4 _FOG;

float4 _FOGCOLORBOTTOM;
float4 _FOGCOLORTOP;

float _FOGTONEDIST;
float _FOGTONEOFFSET;

float _FOGMULT;
float _FOGEFFECTMULT;
int _DITHERLEVELS;
int _DITHERMINIMUM;
float _FOGDITHERAMOUNT;


int _FOGDITHERLEVELS;

//-- LIGHTING --
uniform float4 _LIGHT[32];
uniform float4 _LIGHTCOL[32];
uniform float4 _LIGHTDIR[32]; //Spot light direction and cutoff
uniform float4 _LIGHTFX[32]; //Spot light direction and cutoff

float _SHADING;

//-- VERTEX JITTER --
uniform int _ROUND;
float _ROUNDMULT;
float _USEJITTER;

float _WORLDBRIGHT;
float _ENTITYBRIGHT;
float4 _BRIGHTCOL;

float _FULLBRIGHT;

float _CORRUPTHEIGHT;
sampler2D _CORRUPTTEXTURE;

//-- OTHER EFFECTS --
uniform float4 _WORLDWIGGLE;
uniform float4 _WORLDWARP;

//Dither
sampler2D _DITHERTEXTURE;
float4 _DITHERTEXTURE_TexelSize;
float _DITHEREFFECT;

float Epsilon = 1e-10;

float _GAMMA;

float _OFFSET;



float3 RGBtoHCV(in float3 RGB)
{
    // Based on work by Sam Hocevar and Emil Persson
    float4 P = (RGB.g < RGB.b) ? float4(RGB.bg, -1.0, 2.0/3.0) : float4(RGB.gb, 0.0, -1.0/3.0);
    float4 Q = (RGB.r < P.x) ? float4(P.xyw, RGB.r) : float4(RGB.r, P.yzx);
    float C = Q.x - min(Q.w, Q.y);
    float H = abs((Q.w - Q.y) / (6 * C + Epsilon) + Q.z);
    return float3(H, C, Q.x);
}

float3 HUEtoRGB(in float H)
{
    float R = abs(H * 6 - 3) - 1;
    float G = 2 - abs(H * 6 - 2);
    float B = 2 - abs(H * 6 - 4);
    return saturate(float3(R,G,B));
}

float3 RGBtoHSV(in float3 RGB)
{
    float3 HCV = RGBtoHCV(RGB);
    float S = HCV.y / (HCV.z + Epsilon);
    return float3(HCV.x, S, HCV.z);
}

float3 HSVtoRGB(in float3 HSV)
{
    float3 RGB = HUEtoRGB(HSV.x);
    return ((RGB - 1) * HSV.y + 1) * HSV.z;
}

float ScreenspaceDither(float4 screenPos){
    // ---- GENERAL EFFECTS ----
    float2 screenPosition = screenPos.xy / screenPos.w;
    // Calculate screen-space UVs for the dither texture
    float2 ditherUV = (frac(screenPosition / _DITHERTEXTURE_TexelSize.zw) * _ScreenParams.xy) / 2;

    // Sample the dither texture
    half4 screenspaceDither = tex2D(_DITHERTEXTURE, ditherUV);

    screenspaceDither = lerp(0.5,screenspaceDither,_DITHEREFFECT);

    //General dither.
    return screenspaceDither;//lerp(col.rgb, col.rgb * screenspaceDither.r, _DitherAmount);
}

float PosterizeValue(float value, float levels){
    return round(value * levels) / levels;
}

float3 HSVPosterize(float3 col, float levels){
    //Convert to HSV then desaturate.
    float3 hsv = RGBtoHSV(col.rgb);

    hsv.b = round(hsv.b * levels) / levels;

    return HSVtoRGB(hsv);
}

float4 WarpWorld(float4 pos, float dist){

    dist = max(dist-6,0);

    //Standard warp parameters.
    float warpFrequency = 0.8;
    float warpSpeed = 37.81;

    float4 warpOffset = float4(sin(_Time.x * warpSpeed + (pos.x + pos.z) * warpFrequency), cos(_Time.x * warpSpeed + (pos.x + pos.y) * warpFrequency), sin(_Time.x * warpSpeed + (pos.y + pos.z) * warpFrequency), 0);


    float4 warp = pos + (_WORLDWARP.x * warpOffset * (dist * _WORLDWARP.z));
    return warp;
}

//Overlay function.
float3 Overlay(float3 base, float3 blend, float opacity){
    float3 result;
    result.rgb = (1.0 - 2.0 * blend.rgb) * base.rgb * base.rgb + 2.0 * blend.rgb * base.rgb;
    return lerp(base, result, opacity);
}

lighting Light (lightinput i)
{
    lighting l;
    l.lights         = 0.0f;
    l.lightCol       = 0.0f;
    l.lightmapLights = 0.0f;
    l.bypassLightmap = 0.0f;
    l.emissiveMult = 0.0f;

    // snap to 1/32 voxel grid
    half3 pos = floor(i.vPos * 32.0h + 0.001h) * (1.0h / 32.0h);

    half   negLight = 0.0h;           // we only need a scalar for subtractive
    i.shading = lerp(i.shading, 1, 0.9);

    for (int t = 0; t < 32; t++)
    {
        if(i.lightCount > 0 && t >= i.lightCount) break;
        
        half3 diff   = _LIGHT[t].xyz - pos;
        half  lenSq  = dot(diff, diff) + 1e-4h;
        half  invLen = rsqrt(lenSq);               // 1 / distance

        half  range  = max(_LIGHT[t].w, 1e-3h);
        half  att    = saturate(invLen * (range * 0.6h));

        if(att <= 0.1) continue;

        // face shading
        half ndotl = saturate(dot(i.nrm, diff * invLen));
        att *= max(ndotl, i.shading);

        // spotlight cone
        if (_LIGHTDIR[t].w > 0.5h)
        {
            half3 sd = -diff * invLen;             // to-light dir
            half3 ld = normalize(_LIGHTDIR[t].xyz);
            half  cosCut = cos(radians(_LIGHTDIR[t].w * 0.65h));
            half  cone   = saturate((dot(sd, ld) - cosCut) / (1.0h - cosCut));
            att *= cone;
        }

        half  sign  = _LIGHTCOL[t].w;              // ± intensity
        half  attS  = att * abs(sign);             // signed attenuation

        if (attS < 1e-4h) continue;                // cheap skip

        /* fall-off exponent ------------------------------------------------ */
        half expVal = _LIGHTFX[t].y;               // normally 0-3
        half powAtt = (abs(expVal) < 0.05h) ? attS :
        (abs(expVal - 1.0h) < 0.05h) ? attS*attS :
        (abs(expVal - 2.0h) < 0.05h) ? attS*attS*attS :
        pow(attS, expVal + 1.0h);
        
        half  addSca   = powAtt;
        half3 addCol   = _LIGHTCOL[t].rgb * addSca * addSca;
        half3 lmBypass = _LIGHTCOL[t].rgb * _LIGHTFX[t].x * addSca;

        l.bypassLightmap.rgb = saturate(max(l.bypassLightmap.rgb, lmBypass));
        l.bypassLightmap.a   = 0;                // keep alpha clear

        l.emissiveMult += _LIGHTFX[t].z * addCol;


        if (sign < 0)          // negative light
        {
            negLight = max(negLight, addSca);
        }
        else                   // positive light
        {
            l.lights    = max(l.lights,    addSca);
            l.lightCol  = max(l.lightCol,  float4(addCol, 1.0));
        }
    }

    /* apply subtractive lights once */
    l.lights = max(0, l.lights - negLight);


    /* optional shimmer */
    half shimmer = saturate((sin(dot(i.vertex.xyz, 0.01h) + _Time.x * 100) * 0.5h + 0.1h)
    * i.shimmer * 2.0h);
    l.lights += shimmer;


    return l;
}

float3 CalculateFog(float3 col, float camDist, float dither, float3 worldPos){
    //Fog
    half fogDist = saturate(camDist * _FOGMULT -
    dither * _FOGDITHERAMOUNT);
    half fogPost = max(round(fogDist * _FOGDITHERLEVELS) /
    _FOGDITHERLEVELS, fogDist);
    fogDist      = lerp(fogDist, fogPost, _DITHEREFFECT);

    float expoFog = pow(fogDist, 2);

    float viewDot = dot(float3(0,1,0), normalize(worldPos - _WorldSpaceCameraPos));
    viewDot *= _FOGTONEDIST;
    viewDot += _FOGTONEOFFSET;

    viewDot = (viewDot * 0.5) + 0.5;
    viewDot = clamp(viewDot, 0, 1);

    viewDot = smoothstep(0,1,viewDot);


    // Blend between bottom and top colors
    float3 gradFogColor = lerp(_FOGCOLORBOTTOM.rgb, _FOGCOLORTOP.rgb, viewDot);

    col = lerp(col.rgb, gradFogColor, expoFog);

    return col;
    //Fog End
}

// Rotate a point around an axis (object space) using Rodrigues' rotation formula
float3 RotateAroundAxis(float3 pos, float3 pivot, float3 axis, float angleRad)
{
    // Move into pivot space
    float3 p = pos - pivot;

    axis = normalize(axis);
    float s = sin(angleRad);
    float c = cos(angleRad);

    // Rodrigues' rotation formula: p' = p*c + cross(axis, p)*s + axis*dot(axis,p)*(1-c)
    float3 term1 = p * c;
    float3 term2 = cross(axis, p) * s;
    float3 term3 = axis * dot(axis, p) * (1.0 - c);

    float3 rotated = term1 + term2 + term3;

    // Move back out of pivot space
    return rotated + pivot;
}