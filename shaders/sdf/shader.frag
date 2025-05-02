#version 430 core

out vec4 FragColor;
in vec2 texCoord;

uniform sampler2D tex;

void main()
{
    float color = texture(tex, texCoord).r;
    FragColor = vec4(color, color, color, 1.0);

    // FragColor = vec4(1.0, 0.0, 0.0, 1.0);
    // FragColor = vec4(texCoord.x, texCoord.y, 0.0, 0.0);
}
