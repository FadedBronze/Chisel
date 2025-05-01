#version 430 core

out vec4 FragColor;
in vec2 texCoord;

uniform sampler2D tex;

void main()
{
  //vec4(texture(tex, texCoord).r, 1.0, 1.0, 1.0);
    FragColor = vec4(1.0, 0.0, 0.0, 1.0);
}
