#version 430 core

out vec4 FragColor;
in vec2 texCoord;

uniform sampler2D tex;

void main()
{
    float smoothness = 0.03;

    float sdf = texture(tex, texCoord).r;
    float color = smoothstep(0.5-smoothness, 0.5+smoothness, sdf);
    FragColor = vec4(color, color, color, color);

    // FragColor = vec4(1.0, 0.0, 0.0, 1.0);
    // FragColor = vec4(texCoord.x, texCoord.y, 0.0, 0.0);
}
