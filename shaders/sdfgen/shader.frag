#version 430 core

out vec4 FragColor;
in vec4 vertexColor;

//layout(std430, binding = 0) buffer SSBO {
//};

void main()
{
    FragColor = vertexColor;
}
