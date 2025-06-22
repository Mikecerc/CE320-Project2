/**
* Parallax Mapping Shader
* Description: This shader implements parallax, normal, specular, and gloss mapping
* Class: CS-320 – Project 2 – 2025 Spring
* Michael Cercone
*/
Shader "Unlit/ParallaxMap"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _ParallaxStrength ("Parallax Strength", Float) = 0.025
        _NormalMap ("Normal Map", 2D) = "bump" {}
        _SpecularMap ("Specular Map", 2D) = "white" {}
        _GlossyMap ("Glossy Map", 2D) = "white" {}
        _HeightMap ("Height Map", 2D) = "white" {}
        _ambientColor ("Ambient Color", Color) = (1,1,1,1)

    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 viewDirTS : TEXCOORD1;
                float3 viewDirWS : TEXCOORD2; // View direction in world space
                float3x3 TBN : TEXCOORD3; // Tangent, Bitangent, Normal matrix
            };

            TEXTURE2D(_MainTex);        SAMPLER(sampler_MainTex);
            TEXTURE2D(_NormalMap);      SAMPLER(sampler_NormalMap);
            TEXTURE2D(_SpecularMap);    SAMPLER(sampler_SpecularMap);
            TEXTURE2D(_GlossyMap);      SAMPLER(sampler_GlossyMap);
            TEXTURE2D(_HeightMap);      SAMPLER(sampler_HeightMap);
            float _ParallaxStrength;    
            float4 _ambientColor;

            v2f vert (appdata v)
            {
                v2f OUT;

                // Transform vertex position and normal to world space
                OUT.vertex = TransformObjectToHClip(v.vertex);
                float3 positionWS = TransformObjectToWorld(v.vertex.xyz);
                float3 normalWS = normalize(TransformObjectToWorldNormal(v.normal));
                float3 tangentWS = normalize(TransformObjectToWorldDir(v.tangent.xyz));
                float3 bitangentWS = normalize(cross(normalWS, tangentWS) * v.tangent.w);

                // Create the TBN matrix
                float3x3 TBN = float3x3(tangentWS, bitangentWS, normalWS);

                // Calculate view direction in world space and convert to tangent space
                float3 viewDirWS = normalize(_WorldSpaceCameraPos - positionWS);
                float3 viewDirTS = mul(TBN, viewDirWS); // Convert view direction to tangent space
                OUT.viewDirTS = viewDirTS; // Pass world position for lighting calculations
                OUT.viewDirWS = viewDirWS; // Pass world position for lighting calculations
                OUT.TBN = TBN;
                OUT.uv = v.uv; 

                
                return OUT;
            }
            float2 ApplyParallax(float2 uv, float3 viewDirTS)
                {
                    // Sample the height map to get the parallax offset
                    float height = SAMPLE_TEXTURE2D(_HeightMap, sampler_HeightMap, uv).r;
                    float2 offset = viewDirTS.xy * (height * _ParallaxStrength) ; // Avoid division by zero
                    // Clamp the UV coordinates to prevent out-of-bounds sampling
                    return uv + offset;
                }
            float4 frag (v2f i) : SV_Target
            {
                
                // Apply parallax mapping
                float2 parallaxUV = ApplyParallax(i.uv, i.viewDirTS);

                // Sample textures
                float3 diffuseMap = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, parallaxUV).rgb;
                float3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, parallaxUV));
                float3 normalWS = normalize(mul(i.TBN, normalTS));
                float3 specColor = SAMPLE_TEXTURE2D(_SpecularMap, sampler_SpecularMap, parallaxUV).rgb;
                float smoothness = SAMPLE_TEXTURE2D(_GlossyMap, sampler_GlossyMap, parallaxUV).r;
                
                float3 lightColor = _MainLightColor.rgb;

                float3 lightDirWS = normalize(_MainLightPosition.xyz);
                float NdotL = max(dot(normalWS, lightDirWS), 0);

                // Calculate diffuse and ambient lighting
                float3 diffuse = diffuseMap * NdotL * lightColor;
                float3 ambient = _ambientColor * diffuseMap;

                
                // Calculate specular reflection using Blinn-Phong model
                float3 halfDir = normalize(lightDirWS + i.viewDirWS);
                float NdotH = max(dot(normalWS, halfDir), 0);
                float3 specular = specColor * pow(NdotH, smoothness * 128);

                return float4(diffuse + specular+ ambient, 1.0);
            }
            ENDHLSL

        }
    }
}
