Shader "Custom/AnimeFurniture"
{
    Properties
    {
        [Header(1. Choose What This Material Is For)]
        [Enum(Furniture, 0, Wall_Floor_Ceiling, 1, Window_Glass, 2)] _SurfaceMode ("Surface Mode", Float) = 0

        [Header(2. Colors and Anime Shading)]
        _BaseMap ("Base Texture", 2D) = "white" {}
        _BaseColor ("Base Color / Tint", Color) = (1, 1, 1, 1)
        _ShadowColor ("Anime Shadow Tint", Color) = (0.62, 0.56, 0.75, 1)
        _Threshold ("Shadow Threshold", Range(0.05, 0.9)) = 0.25
        _Smoothness ("Toon Edge Softness", Range(0.001, 0.1)) = 0.015
        _SunBrightness ("Sunlight Brightness Boost", Range(1.0, 2.0)) = 1.25
        _LampBrightness ("Lamp / Point Light Strength", Range(0.0, 3.0)) = 1.2

        [Header(3. Outline Settings)]
        _OutlineColor ("Outline / Frame Color", Color) = (0.12, 0.09, 0.16, 1)
        _OutlineWidth ("Furniture 3D Outline Width", Range(0, 0.04)) = 0.007
        _CornerWidth ("Room Corner Line Width (Walls)", Range(0, 0.05)) = 0.018

        [Header(4. Window Glass Settings)]
        _GlassAlpha ("Window Glass Opacity", Range(0.05, 0.9)) = 0.25
        _WindowFrameWidth ("Window Frame Border Width", Range(0.0, 0.15)) = 0.045
        _GlassShine ("Anime Glass Reflection Streaks", Range(0.0, 1.0)) = 0.45
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }

        // =================================================================
        // PASS 1: ANIME CEL-SHADING (SUN + LAMPS), WALL CORNERS & GLASS
        // =================================================================
        Pass
        {
            Name "AnimeForward"
            Tags { "LightMode" = "UniversalForward" }

            Cull Back
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite On

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _FORWARD_PLUS
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half4 _ShadowColor;
                half4 _OutlineColor;
                half _SurfaceMode;
                half _Threshold;
                half _Smoothness;
                half _SunBrightness;
                half _LampBrightness;
                half _OutlineWidth;
                half _CornerWidth;
                half _GlassAlpha;
                half _WindowFrameWidth;
                half _GlassShine;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS   : TEXCOORD1;
                float2 uv         : TEXCOORD2;
                float3 positionOS : TEXCOORD3;
                float3 normalOS   : TEXCOORD4;
            };

            Varyings vert(Attributes v)
            {
                Varyings o;
                VertexPositionInputs p = GetVertexPositionInputs(v.positionOS.xyz);

                o.positionCS = p.positionCS;
                o.positionWS = p.positionWS;
                o.normalWS   = TransformObjectToWorldNormal(v.normalOS);
                o.uv         = TRANSFORM_TEX(v.uv, _BaseMap);
                o.positionOS = v.positionOS.xyz;
                o.normalOS   = v.normalOS;
                return o;
            }

            half4 frag(Varyings i) : SV_Target
            {
                // ---------------------------------------------------------
                // MODE 2: TRANSPARENT ANIME WINDOW GLASS
                // ---------------------------------------------------------
                if (_SurfaceMode > 1.5)
                {
                    float2 uvDist = min(i.uv, 1.0 - i.uv);
                    float minUV = min(uvDist.x, uvDist.y);
                    if (minUV < _WindowFrameWidth)
                    {
                        return half4(_OutlineColor.rgb, 1.0);
                    }

                    float diag = frac(i.uv.x * 0.75 + i.uv.y);
                    float streak1 = smoothstep(0.40, 0.41, diag) - smoothstep(0.46, 0.47, diag);
                    float streak2 = smoothstep(0.51, 0.52, diag) - smoothstep(0.54, 0.55, diag);
                    float shine = saturate(streak1 + streak2) * _GlassShine;

                    half3 glassColor = lerp(_BaseColor.rgb, half3(1.0, 1.0, 1.0), shine);
                    half finalAlpha = saturate(_GlassAlpha + shine * 0.65);
                    return half4(glassColor, finalAlpha);
                }

                // ---------------------------------------------------------
                // MODE 1: WALL, FLOOR & CEILING INTERIOR CORNER OUTLINES
                // ---------------------------------------------------------
                if (_SurfaceMode > 0.5 && _SurfaceMode < 1.5)
                {
                    float3 objScale = float3(
                        length(unity_ObjectToWorld._m00_m10_m20),
                        length(unity_ObjectToWorld._m01_m11_m21),
                        length(unity_ObjectToWorld._m02_m12_m22)
                    );

                    int fullAxes = (objScale.x >= 2.8 ? 1 : 0)
                                 + (objScale.y >= 2.8 ? 1 : 0)
                                 + (objScale.z >= 2.8 ? 1 : 0);

                    if (fullAxes >= 2 && _CornerWidth > 0.0001)
                    {
                        float3 distToEdge = (0.5 - abs(i.positionOS)) * objScale;
                        float3 absObjNormal = abs(normalize(i.normalOS));

                        bool isCorner = false;
                        if (absObjNormal.x < 0.5 && objScale.x >= 2.8 && distToEdge.x < (_CornerWidth + 0.05))
                            isCorner = true;
                        if (absObjNormal.y < 0.5 && objScale.y >= 2.8 && distToEdge.y < _CornerWidth)
                            isCorner = true;
                        if (absObjNormal.z < 0.5 && objScale.z >= 2.8 && distToEdge.z < (_CornerWidth + 0.05))
                            isCorner = true;

                        if (isCorner)
                        {
                            return half4(_OutlineColor.rgb, 1.0);
                        }
                    }
                }

                // ---------------------------------------------------------
                // 1. MAIN DIRECTIONAL SUNLIGHT (WITH REAL WINDOW SHADOWS)
                // ---------------------------------------------------------
                half4 tex = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv) * _BaseColor;
                float3 normalWS = normalize(i.normalWS);

                float4 shadowCoord = TransformWorldToShadowCoord(i.positionWS);
                Light mainLight = GetMainLight(shadowCoord);

                // Unwrapped NdotL so surfaces facing away from the light stay in shadow
                half ndotl = saturate(dot(normalWS, normalize(mainLight.direction)));
                half litStep = smoothstep(_Threshold - _Smoothness, _Threshold + _Smoothness, ndotl);
                half shadowStep = smoothstep(0.35, 0.65, mainLight.shadowAttenuation);
                half sunLit = litStep * shadowStep;

                // Clearly contrast Shadowed areas vs Sunlit areas
                half3 shadowState = tex.rgb * _ShadowColor.rgb;
                half3 sunlitState = tex.rgb * mainLight.color * _SunBrightness;
                half3 finalRGB = lerp(shadowState, sunlitState, sunLit);

                // ---------------------------------------------------------
                // 2. POINT LIGHTS & LAMPS (UNITY 6 FORWARD & FORWARD+ LOOP)
                // ---------------------------------------------------------
                InputData inputData = (InputData)0;
                inputData.positionWS = i.positionWS;
                inputData.normalWS = normalWS;
                inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(i.positionWS);
                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(i.positionCS);

                half3 lampLightTotal = half3(0, 0, 0);

                #if defined(_FORWARD_PLUS)
                UNITY_LOOP for (uint dirIndex = 0; dirIndex < min(URP_FP_DIRECTIONAL_LIGHTS_COUNT, MAX_VISIBLE_LIGHTS); dirIndex++)
                {
                    Light addDirLight = GetAdditionalLight(dirIndex, inputData.positionWS, half4(1, 1, 1, 1));
                    half dNdotL = saturate(dot(normalWS, addDirLight.direction));
                    half dAtten = addDirLight.distanceAttenuation * addDirLight.shadowAttenuation;
                    half dToon = smoothstep(0.05, 0.15, dNdotL * dAtten);
                    lampLightTotal += addDirLight.color * dToon;
                }
                #endif

                #if defined(_ADDITIONAL_LIGHTS) || defined(_FORWARD_PLUS)
                uint pixelLightCount = GetAdditionalLightsCount();
                LIGHT_LOOP_BEGIN(pixelLightCount)
                    Light addLight = GetAdditionalLight(lightIndex, inputData.positionWS, half4(1, 1, 1, 1));
                    half addNdotL = saturate(dot(normalWS, addLight.direction));
                    half addAtten = addLight.distanceAttenuation * addLight.shadowAttenuation;
                    half lightSignal = addNdotL * addAtten;

                    // Two-step anime light pool (soft outer ring + bright inner core)
                    half outerRing = smoothstep(0.015, 0.04, lightSignal);
                    half innerCore = smoothstep(0.18, 0.25, lightSignal);
                    half toonLamp = outerRing * 0.45 + innerCore * 0.55;

                    lampLightTotal += addLight.color * toonLamp * _LampBrightness;
                LIGHT_LOOP_END
                #endif

                // Add lamp light directly onto the object and wall surfaces
                finalRGB += tex.rgb * lampLightTotal;

                return half4(finalRGB, 1.0);
            }
            ENDHLSL
        }

        // =================================================================
        // PASS 2: 3D INK OUTLINE (ONLY RUNS ON FURNITURE)
        // =================================================================
        Pass
        {
            Name "AnimeOutline"
            Tags { "LightMode" = "SRPDefaultUnlit" }

            Cull Front
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM
            #pragma vertex outlineVert
            #pragma fragment outlineFrag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half4 _ShadowColor;
                half4 _OutlineColor;
                half _SurfaceMode;
                half _Threshold;
                half _Smoothness;
                half _SunBrightness;
                half _LampBrightness;
                half _OutlineWidth;
                half _CornerWidth;
                half _GlassAlpha;
                half _WindowFrameWidth;
                half _GlassShine;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };

            Varyings outlineVert(Attributes v)
            {
                Varyings o;
                float3 pos = TransformObjectToWorld(v.positionOS.xyz);
                float3 n = TransformObjectToWorldNormal(v.normalOS);

                float width = (_SurfaceMode < 0.5) ? _OutlineWidth : 0.0;
                pos += n * width;

                o.positionCS = TransformWorldToHClip(pos);
                return o;
            }

            half4 outlineFrag(Varyings i) : SV_Target
            {
                if (_SurfaceMode > 0.5 || _OutlineWidth <= 0.0001)
                {
                    clip(-1);
                }
                return half4(_OutlineColor.rgb, 1.0);
            }
            ENDHLSL
        }

        // =================================================================
        // PASS 3: SHADOW CASTER (SO WALLS & FURNITURE CAST REAL SHADOWS)
        // =================================================================
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back

            HLSLPROGRAM
            #pragma vertex shadowVert
            #pragma fragment shadowFrag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                half4 _BaseColor;
                half4 _ShadowColor;
                half4 _OutlineColor;
                half _SurfaceMode;
                half _Threshold;
                half _Smoothness;
                half _SunBrightness;
                half _LampBrightness;
                half _OutlineWidth;
                half _CornerWidth;
                half _GlassAlpha;
                half _WindowFrameWidth;
                half _GlassShine;
            CBUFFER_END

            float3 _LightDirection;

            struct ShadowAttributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct ShadowVaryings
            {
                float4 positionCS : SV_POSITION;
            };

            ShadowVaryings shadowVert(ShadowAttributes v)
            {
                ShadowVaryings o;
                float3 positionWS = TransformObjectToWorld(v.positionOS.xyz);
                float3 normalWS = TransformObjectToWorldNormal(v.normalOS);

                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));
                #if UNITY_REVERSED_Z
                    positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #else
                    positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
                #endif

                o.positionCS = positionCS;
                return o;
            }

            half4 shadowFrag(ShadowVaryings i) : SV_Target
            {
                // Window Glass (SurfaceMode == 2) never casts shadows so sunlight shines through!
                if (_SurfaceMode > 1.5)
                {
                    clip(-1);
                }
                return 0;
            }
            ENDHLSL
        }
    }
    FallBack Off
}