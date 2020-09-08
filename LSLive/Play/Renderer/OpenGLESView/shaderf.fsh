varying highp vec2 textureCoordinate;

uniform sampler2D textureSamplerY;
uniform sampler2D texutreSamplerUV;
uniform mediump mat3 colorConversionMatrix;

void main()
{
    mediump vec3 yuv;
    lowp vec3 rgb;
    
    yuv.x = texture2D(textureSamplerY, textureCoordinate).r - (16.0/255.0);
    yuv.yz = texture2D(texutreSamplerUV, textureCoordinate).ra - vec2(0.5, 0.5);
    rgb = colorConversionMatrix * yuv;
    
    gl_FragColor = vec4(rgb, 1);
}
