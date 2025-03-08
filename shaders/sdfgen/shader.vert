#version 430 core

layout (location = 0) in vec2 aPos;
layout (location = 1) in vec4 aIndex;

out vec4 vertexColor;

void main()
{
    vertexColor = vec4(1.0, 0.0, 0.0, 1.0);
    gl_Position = vec4(aPos.x, aPos.y, 0.0, 1.0);
}
