//
//  Shader.vsh
//  Sample
//
//  Created by Jack Tsai on 3/4/16.
//  Copyright © 2016 Jack Tsai. All rights reserved.
//
precision mediump float;

attribute vec4 position;
attribute vec3 normal;
attribute vec2 texCoordIn;

varying vec3 eyeNormal;
varying vec4 eyePos;
varying vec2 texCoordOut;

uniform mat4 modelViewProjectionMatrix;
uniform mat4 modelViewMatrix;
uniform mat3 normalMatrix;

void main()
{
    eyeNormal = normalize(normalMatrix * normal);
    eyePos = modelViewMatrix * position;
    
    // Pass through texture
    texCoordOut = texCoordIn;
    
    gl_Position = modelViewProjectionMatrix * position;
}
