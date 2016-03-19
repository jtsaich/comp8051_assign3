//
//  GameViewController.m
//  Sample
//
//  Created by Jack Tsai on 3/4/16.
//  Copyright © 2016 Jack Tsai. All rights reserved.
//

#import "GameViewController.h"
#import <OpenGLES/ES2/glext.h>

#import "CMazeHandler.h"
#import "cube.h"
#import "dog.h"

#define BUFFER_OFFSET(i) ((char *)NULL + (i))

// Uniform index.
enum
{
    UNIFORM_MODELVIEWPROJECTION_MATRIX,
    UNIFORM_NORMAL_MATRIX,
    UNIFORM_MODELVIEW_MATRIX,
    UNIFORM_TEXTURE,
    UNIFORM_FLASHLIGHT_POSITION,
    UNIFORM_DIFFUSE_LIGHT_POSITION,
    UNIFORM_SHININESS,
    UNIFORM_AMBIENT_COMPONENT,
    UNIFORM_DIFFUSE_COMPONENT,
    UNIFORM_SPECULAR_COMPONENT,
    UNIFORM_FOG_DENSITY,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// Attribute index.
enum
{
    ATTRIB_VERTEX,
    ATTRIB_NORMAL,
    NUM_ATTRIBUTES
};

// Camera direction index.
enum
{
    NORTH,
    EAST,
    SOUTH,
    WEST
};

// Game action index.
enum
{
    NO_ACTION,
    TURN_LEFT,
    TURN_RIGHT
};

// plane data to draw floor, wall, crate
GLfloat planeVertexData[] =
{
    -0.5f, 0.0f, 0.5f,
    -0.5f, 0.0f, -0.5f,
    0.5f, 0.0f, -0.5f,
    0.5f, 0.0f, 0.5f
};

GLfloat planelNormals[] =
{
    0.0f, 1.0f, 0.0f,
    0.0f, 1.0f, 0.0f,
    0.0f, 1.0f, 0.0f,
    0.0f, 1.0f, 0.0f
};

GLfloat planeTex[] =
{
    0.0f, 0.0f,
    0.0f, 1.0f,
    1.0f, 1.0f,
    1.0f, 0.0f
};

GLuint planeIndices[] =
{
    0, 2, 1,
    0, 3, 2
};

@interface GameViewController () {
    GLuint _program;
    
    GLKMatrix4 _floorModelViewProjectionMatrix[16];
    GLKMatrix3 _floorNormalMatrix[16];
    GLKMatrix4 _floorModelViewMatrix[16];
    
    GLKMatrix4 _wallModelViewProjectionMatrix[64];
    GLKMatrix3 _wallNormalMatrix[64];
    GLKMatrix4 _wallModelViewMatrix[64];
    
    GLKMatrix4 _crateModelViewProjectionMatrix[6];
    GLKMatrix3 _crateNormalMatrix[6];
    GLKMatrix4 _crateModelViewMatrix[16];
    
    GLKMatrix4 _dogModelViewProjectionmatrix;
    GLKMatrix3 _dogNormalMatrix;
    GLKMatrix4 _dogModelViewMatrix;
    
    
    GLKMatrix4 _projectionMatrix;
    int _cameraDirection;
    
    float _crateRotation;
    int _action;
    int _mazeRow;
    int _mazeCol;
    
    bool fogOn;
    bool nightOn;
    bool flashLightOn;
    bool modelMoving;
    bool canControl;
    
    GLKVector3 flashlightPosition;
    GLKVector3 diffuseLightPosition;
    GLKVector4 diffuseComponent;
    GLfloat shininess;
    GLKVector4 specularComponent;
    GLKVector4 ambientComponent;
    GLfloat fogDensity;
    
    /* texture parameters */
    GLuint floorTexture;
    GLuint wallTexture;
    GLuint wall2Texture;
    GLuint wall3Texture;
    GLuint wall4Texture;
    GLuint crateTexture;
    GLuint dogTexture;
    
    
    GLuint _vertexArray[2];
    
    // plane
    GLuint _vertexBuffers[3];
    GLuint _indexBuffer;
    
    // dog modle
    GLuint _dogVerteBuffers[3];
    GLuint _dogIndexBuffer;
    
    
    GLuint _textureBuffers[7];
    
    CGPoint _dragOldLocation;
    GLfloat _cameraYRotation;
    GLKVector3 _cameraPosition;
    
    float deltaX, deltaZ;
    GLKVector3 modelPosition;
    float modelScale;
    float modelRotation;
}

@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) CMazeHandler* maze;

- (void)setupGL;
- (void)tearDownGL;

- (BOOL)loadShaders;
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;
- (BOOL)linkProgram:(GLuint)prog;
- (BOOL)validateProgram:(GLuint)prog;
@end

@implementation GameViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    _mazeRow = 4;
    _mazeCol = 4;
    self.maze = [[CMazeHandler alloc] init:_mazeRow cols:_mazeCol];
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
    [self setupGL];
    
    // touch inputs
    UITapGestureRecognizer *doubleTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hanldeDoubleTapFrom:)];
    doubleTapRecognizer.numberOfTapsRequired = 2;
    [self.view addGestureRecognizer:doubleTapRecognizer];
    
    
    UIPanGestureRecognizer *dragRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleDragFrom:)];
    dragRecognizer.maximumNumberOfTouches = 1;
    [self.view addGestureRecognizer:dragRecognizer];
    
    UILongPressGestureRecognizer *longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressFrom:)];
    [self.view addGestureRecognizer:longPressRecognizer];
    
    UITapGestureRecognizer *tripleFingerTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleModelMovement:)];
    tripleFingerTap.numberOfTapsRequired = 2;
    tripleFingerTap.numberOfTouchesRequired = 2;
    [self.view addGestureRecognizer:tripleFingerTap];
    
    UIPanGestureRecognizer *modelMoveGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveModel:)];
    modelMoveGesture.minimumNumberOfTouches = 2;
    modelMoveGesture.maximumNumberOfTouches = 3;
    [self.view addGestureRecognizer:modelMoveGesture];
    
    UIPinchGestureRecognizer *scaleGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(scaleModel:)];
    scaleGesture.delegate = self;
    [self.view addGestureRecognizer:scaleGesture];
    
    
    UIRotationGestureRecognizer *rotationGesture = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(rotateModel:)];
    rotationGesture.delegate = self;
    [self.view addGestureRecognizer:rotationGesture];
    
    modelPosition = GLKVector3Make(0, 0, -1);
    modelScale = 0.05f;
    modelRotation = 0;
    deltaX = 0.01;
    deltaZ = 0.01;
    
}

- (void)dealloc
{    
    [self tearDownGL];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];

    if ([self isViewLoaded] && ([[self view] window] == nil)) {
        self.view = nil;
        
        [self tearDownGL];
        
        if ([EAGLContext currentContext] == self.context) {
            [EAGLContext setCurrentContext:nil];
        }
        self.context = nil;
    }

    // Dispose of any resources that can be recreated.
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    
    [self loadShaders];
    
    // initial lighting settings
    flashlightPosition = GLKVector3Make(_cameraPosition.x, 0.0, _cameraPosition.z);
    diffuseLightPosition = GLKVector3Make(0, 1.0, 0);
    diffuseComponent = GLKVector4Make(0.8, 0.1, 0.1, 1.0);
    shininess = 300.0;
    specularComponent = GLKVector4Make(1.0, 1.0, 1.0, 1.0);
    ambientComponent = GLKVector4Make(0.6, 0.6, 0.6, 1.0);
    fogDensity = 0.0;
    
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);
    
    // setup VBOs/VAOs
    glGenVertexArraysOES(2, _vertexArray);
    glBindVertexArrayOES(_vertexArray[0]);

    glGenBuffers(3, _vertexBuffers);
    glGenBuffers(1, &_indexBuffer);
    
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffers[0]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(planeVertexData), planeVertexData, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 3*sizeof(float), BUFFER_OFFSET(0));
    
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffers[1]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(planelNormals), planelNormals, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(GLKVertexAttribNormal);
    glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, 3*sizeof(float), BUFFER_OFFSET(0));
    
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffers[2]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(planeTex), planeTex, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, 2*sizeof(float), BUFFER_OFFSET(0));
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(planeIndices), planeIndices, GL_STATIC_DRAW);
    
    
    glBindVertexArrayOES(_vertexArray[1]);
    
    glGenBuffers(3, _dogVerteBuffers);
    
    glBindBuffer(GL_ARRAY_BUFFER, _dogVerteBuffers[0]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat)*3*dogVertices, dogPositions, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 3*sizeof(float), BUFFER_OFFSET(0));
    
    glBindBuffer(GL_ARRAY_BUFFER, _dogVerteBuffers[1]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat)*3*dogVertices, dogNormals, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(GLKVertexAttribNormal);
    glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, 3*sizeof(float), BUFFER_OFFSET(0));
    
    glBindBuffer(GL_ARRAY_BUFFER, _dogVerteBuffers[2]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat)*3*dogVertices, dogTexels, GL_STATIC_DRAW);
    
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, 2*sizeof(float), BUFFER_OFFSET(0));
    
    glBindVertexArrayOES(0);
    
    // load textures
    floorTexture = [self setupTexture:@"floor.jpg"];
    wallTexture = [self setupTexture:@"wall.jpg"];
    wall2Texture = [self setupTexture:@"wall2.jpg"];
    wall3Texture = [self setupTexture:@"wall3.jpg"];
    wall4Texture = [self setupTexture:@"wall4.jpg"];
    crateTexture = [self setupTexture:@"crate.jpg"];
    dogTexture = [self setupTexture:@"dog.png"];
    
    
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
    
    glDeleteBuffers(3, _vertexBuffers);
    glDeleteVertexArraysOES(1, &_vertexArray);
    
    
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)update
{
    if (fogOn) {
        fogDensity = 0.6;
    } else {
        fogDensity = 0;
    }
    
    if (nightOn) {
        ambientComponent = GLKVector4Make(0.2, 0.2, 0.2, 1.0);
    } else {
        ambientComponent = GLKVector4Make(0.6, 0.6, 0.6, 1.0);
    }
    
    if (flashLightOn) {
        shininess = 300.0;
        specularComponent = GLKVector4Make(1.0, 1.0, 1.0, 1.0);
    } else {
        shininess = 300.0;
        specularComponent = GLKVector4Make(0.0, 0.0, 0.0, 1.0);
    }
    
    // testing
//    _cameraYRotation += 0.001f;
    float aspect = fabs(self.view.bounds.size.width / self.view.bounds.size.height);
    _projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f); // facing -z
    _projectionMatrix = GLKMatrix4RotateY(_projectionMatrix, _cameraYRotation);
    _projectionMatrix = GLKMatrix4TranslateWithVector3(_projectionMatrix, _cameraPosition);
    
    for (int i = 0; i < 4 * _mazeRow * _mazeCol; i++) {
        int row = i / 4 % 4;
        int col = i / 4 / 4;
        
        
        _action = NO_ACTION;
        
        GLKMatrix4 baseModelViewMatrix = GLKMatrix4Identity;
        baseModelViewMatrix = GLKMatrix4Translate(baseModelViewMatrix, row, 0, -col);
        
        // create floor modelViewMatrix for each cell
        if (i % 4 == 0) {
            _floorModelViewMatrix[i / 4] = GLKMatrix4MakeTranslation(0, -0.5f, 0);
            _floorModelViewMatrix[i / 4] = GLKMatrix4Multiply(baseModelViewMatrix, _floorModelViewMatrix[i / 4]);
            _floorNormalMatrix[i / 4] = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(_floorModelViewMatrix[i / 4]), NULL);
            _floorModelViewProjectionMatrix[i / 4] = GLKMatrix4Multiply(_projectionMatrix, _floorModelViewMatrix[i / 4]);

        }
        
        
        // create wall modelViewMatrix for North/East/South/West
        _wallModelViewMatrix[i] = GLKMatrix4Identity;
        switch (i % 4) {
            case 0:
                _wallModelViewMatrix[i] = GLKMatrix4RotateX(_wallModelViewMatrix[i], -M_PI_2);
                _wallModelViewMatrix[i] = GLKMatrix4Translate(_wallModelViewMatrix[i], 0, -0.5f, 0);
                break;
            case 1:
                _wallModelViewMatrix[i] = GLKMatrix4RotateZ(_wallModelViewMatrix[i], M_PI_2);
                _wallModelViewMatrix[i] = GLKMatrix4Translate(_wallModelViewMatrix[i], 0, -0.5f, 0);
                break;
            case 2:
                _wallModelViewMatrix[i] = GLKMatrix4RotateX(_wallModelViewMatrix[i], M_PI_2);
                _wallModelViewMatrix[i] = GLKMatrix4Translate(_wallModelViewMatrix[i], 0, -0.5f, 0);
                break;
            case 3:
                _wallModelViewMatrix[i] = GLKMatrix4RotateZ(_wallModelViewMatrix[i], -M_PI_2);
                _wallModelViewMatrix[i] = GLKMatrix4Translate(_wallModelViewMatrix[i], 0, -0.5f, 0);
                break;
            default:
                break;
        }
        
        _wallModelViewMatrix[i] = GLKMatrix4Multiply(baseModelViewMatrix, _wallModelViewMatrix[i]);
        _wallNormalMatrix[i] = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(_wallModelViewMatrix[i]), NULL);
        _wallModelViewProjectionMatrix[i] = GLKMatrix4Multiply(_projectionMatrix, _wallModelViewMatrix[i]);
    }
    
    
    // generate movelViewMatrix of the rotating crate
    GLKMatrix4 baseModelViewMatrix = GLKMatrix4MakeTranslation(0, 0, -1);
    
    for (int i = 0; i < 6; i++) {
        _crateModelViewMatrix[i] = GLKMatrix4Identity;
        
        _crateModelViewMatrix[i] = GLKMatrix4Rotate(_crateModelViewMatrix[i], _crateRotation, 1.0f, 1.0f, 1.0f);
        _crateModelViewMatrix[i] = GLKMatrix4Scale(_crateModelViewMatrix[i], 0.2f, 0.2f, 0.2f);
        switch (i % 6) {
            case 0:
                _crateModelViewMatrix[i] = GLKMatrix4RotateX(_crateModelViewMatrix[i], M_PI_2);
                _crateModelViewMatrix[i] = GLKMatrix4Translate(_crateModelViewMatrix[i], 0, 0.5f, 0);
                break;
            case 1:
                _crateModelViewMatrix[i] = GLKMatrix4RotateZ(_crateModelViewMatrix[i], -M_PI_2);
                _crateModelViewMatrix[i] = GLKMatrix4Translate(_crateModelViewMatrix[i], 0, 0.5f, 0);
                break;
            case 2:
                _crateModelViewMatrix[i] = GLKMatrix4RotateX(_crateModelViewMatrix[i], -M_PI_2);
                _crateModelViewMatrix[i] = GLKMatrix4Translate(_crateModelViewMatrix[i], 0, 0.5f, 0);
                break;
            case 3:
                _crateModelViewMatrix[i] = GLKMatrix4RotateZ(_crateModelViewMatrix[i], M_PI_2);
                _crateModelViewMatrix[i] = GLKMatrix4Translate(_crateModelViewMatrix[i], 0, 0.5f, 0);
                break;
            case 4:
                _crateModelViewMatrix[i] = GLKMatrix4Translate(_crateModelViewMatrix[i], 0, 0.5f, 0);
                break;
            case 5:
                _crateModelViewMatrix[i] = GLKMatrix4RotateX(_crateModelViewMatrix[i], M_PI);
                _crateModelViewMatrix[i] = GLKMatrix4Translate(_crateModelViewMatrix[i], 0, 0.5f, 0);
                break;
            default:
                break;
        }
        
        _crateModelViewMatrix[i] = GLKMatrix4Multiply(baseModelViewMatrix, _crateModelViewMatrix[i]);
        _crateNormalMatrix[i] = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(_crateModelViewMatrix[i]), NULL);
        _crateModelViewProjectionMatrix[i] = GLKMatrix4Multiply(_projectionMatrix, _crateModelViewMatrix[i]);
    }
    
    if(modelMoving){
        [self updateModelPosition];
    }
    
    _dogModelViewMatrix = GLKMatrix4Identity;
    _dogModelViewMatrix = GLKMatrix4Translate(_dogModelViewMatrix, 0, -0.5f, 0);
    _dogModelViewMatrix = GLKMatrix4TranslateWithVector3(_dogModelViewMatrix, modelPosition);
    _dogModelViewMatrix = GLKMatrix4Scale(_dogModelViewMatrix, modelScale, modelScale, modelScale);
    _dogModelViewMatrix = GLKMatrix4RotateY(_dogModelViewMatrix, modelRotation);
    // _dogModelViewMatrix = GLKMatrix4Scale(_dogModelViewMatrix, 0.05f, 0.05f, 0.05f);
    _dogModelViewMatrix = GLKMatrix4RotateY(_dogModelViewMatrix, M_PI_2);
    // _dogModelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, _dogModelViewMatrix);
    _dogNormalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(_dogModelViewMatrix), NULL);
    _dogModelViewProjectionmatrix = GLKMatrix4Multiply(_projectionMatrix, _dogModelViewMatrix);
    
    _crateRotation += self.timeSinceLastUpdate * 0.5f;
    
    canControl = [self sameCell:modelPosition :_cameraPosition];

}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClearColor(0.65f, 0.65f, 0.65f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    
    // Render the object again with ES2
    glUseProgram(_program);
    
    glUniform3fv(uniforms[UNIFORM_FLASHLIGHT_POSITION], 1, flashlightPosition.v);
    glUniform3fv(uniforms[UNIFORM_DIFFUSE_LIGHT_POSITION], 1, diffuseLightPosition.v);
    glUniform4fv(uniforms[UNIFORM_DIFFUSE_COMPONENT], 1, diffuseComponent.v);
    glUniform1f(uniforms[UNIFORM_SHININESS], shininess);
    glUniform4fv(uniforms[UNIFORM_SPECULAR_COMPONENT], 1, specularComponent.v);
    glUniform4fv(uniforms[UNIFORM_AMBIENT_COMPONENT], 1, ambientComponent.v);
    glUniform1f(uniforms[UNIFORM_FOG_DENSITY], fogDensity);
    
    
    glBindVertexArrayOES(_vertexArray[1]);
    
    glBindTexture(GL_TEXTURE_2D, dogTexture);
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _dogModelViewProjectionmatrix.m);
    glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, _dogNormalMatrix.m);
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEW_MATRIX], 1, 0, _dogModelViewMatrix.m);
    glDrawArrays(GL_TRIANGLES, 0, dogVertices);
    
    
    glBindVertexArrayOES(_vertexArray[0]);
    // draw crate
    for (int i = 0; i < 6; i++) {
        glBindTexture(GL_TEXTURE_2D, crateTexture);
        glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _crateModelViewProjectionMatrix[i].m);
        glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, _crateNormalMatrix[i].m);
        glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEW_MATRIX], 1, 0, _crateModelViewMatrix[i].m);
        
        // Select VBO and draw
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
        glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
    }
    
    // draw floors
    for (int i = 0; i < 16; i++) {
        glBindTexture(GL_TEXTURE_2D, floorTexture);
        glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _floorModelViewProjectionMatrix[i].m);
        glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, _floorNormalMatrix[i].m);
        glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEW_MATRIX], 1, 0, _floorModelViewMatrix[i].m);
        
        // Select VBO and draw
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
        glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
    }
    
    // draw walls
    for (int i = 0; i < 64; i+=4) {
        int row = i / 4 % 4;
        int col = i / 4 / 4;
        
        if ([self.maze northWallPresent:row col:col] && [self.maze southWallPresent:row col:col]) {
            glBindTexture(GL_TEXTURE_2D, wallTexture);
            [self drawWall:i];
            [self drawWall:i+2];
            
        } else if (![self.maze northWallPresent:row col:col] && ![self.maze southWallPresent:row col:col]) {
            glBindTexture(GL_TEXTURE_2D, wall2Texture);
        } else if ([self.maze northWallPresent:row col:col]) {
            glBindTexture(GL_TEXTURE_2D, wall3Texture);
            [self drawWall:i];
        } else {
            glBindTexture(GL_TEXTURE_2D, wall4Texture);
            [self drawWall:i+2];
        }
        
        if ([self.maze westWallPresent:row col:col] && [self.maze eastWallPresent:row col:col]) {
            glBindTexture(GL_TEXTURE_2D, wallTexture);
            [self drawWall:i+1];
            [self drawWall:i+3];
            
        } else if (![self.maze westWallPresent:row col:col] && ![self.maze eastWallPresent:row col:col]) {
            glBindTexture(GL_TEXTURE_2D, wall2Texture);
        } else if ([self.maze westWallPresent:row col:col]) {
            glBindTexture(GL_TEXTURE_2D, wall3Texture);
            [self drawWall:i+1];
        } else {
            glBindTexture(GL_TEXTURE_2D, wall4Texture);
            [self drawWall:i+3];
        }
    }
}

- (void)drawWall:(int)i
{
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _wallModelViewProjectionMatrix[i].m);
    glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, _wallNormalMatrix[i].m);
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEW_MATRIX], 1, 0, _wallModelViewMatrix[i].m);
    
    // Select VBO and draw
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);
}

#pragma mark -  Input Handling
- (void)hanldeDoubleTapFrom:(UITapGestureRecognizer *)recognizer {
//    float aspect = fabs(self.view.bounds.size.width / self.view.bounds.size.height);
//    _projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
//    _projectionMatrix = GLKMatrix4RotateY(_projectionMatrix, M_PI);
//    _cameraDirection = SOUTH;
//    _cameraPosition = GLKVector3Make(0, 0, 0);
    
    
    GLKMatrix4 transform = GLKMatrix4Identity;
    // move camera back to origin
    transform = GLKMatrix4TranslateWithVector3(transform, GLKVector3Negate(_cameraPosition));
    
    // rotate to original angle, move forward, adjust back to previous rotation
    transform = GLKMatrix4RotateY(transform, -_cameraYRotation);
    transform = GLKMatrix4Translate(transform, 0, 0, 1);
    transform = GLKMatrix4RotateY(transform, _cameraYRotation);
    
    // move camera back to previous position
    transform = GLKMatrix4TranslateWithVector3(transform, _cameraPosition);
    
    _cameraPosition = GLKMatrix4MultiplyVector3WithTranslation(transform, _cameraPosition);
    
    NSLog(@"New camera rotation: %f", _cameraYRotation);
    NSLog(@"New camera position: %f, %f, %f", _cameraPosition.x, _cameraPosition.y, _cameraPosition.z);
    
}

- (void)handleDragFrom:(UIPanGestureRecognizer *)recognizer {
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        _dragOldLocation = [recognizer locationInView:recognizer.view];
    } else {
        CGPoint currentLocation = [recognizer locationInView:recognizer.view];
        CGFloat dx = currentLocation.x - _dragOldLocation.x;
        CGFloat dy = currentLocation.y - _dragOldLocation.y;
        _cameraYRotation += (dx * 0.005f);
        _dragOldLocation = currentLocation;
    }
}

- (void)handleLongPressFrom:(UILongPressGestureRecognizer *)recognizer {
}

#pragma mark -  OpenGL ES 2 shader compilation

- (BOOL)loadShaders
{
    GLuint vertShader, fragShader;
    NSString *vertShaderPathname, *fragShaderPathname;
    
    // Create shader program.
    _program = glCreateProgram();
    
    // Create and compile vertex shader.
    vertShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderPathname]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }
    
    // Create and compile fragment shader.
    fragShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }
    
    // Attach vertex shader to program.
    glAttachShader(_program, vertShader);
    
    // Attach fragment shader to program.
    glAttachShader(_program, fragShader);
    
    // Bind attribute locations.
    // This needs to be done prior to linking.
    glBindAttribLocation(_program, GLKVertexAttribPosition, "position");
    glBindAttribLocation(_program, GLKVertexAttribNormal, "normal");
    glBindAttribLocation(_program, GLKVertexAttribTexCoord0, "texCoordIn");
    
    // Link program.
    if (![self linkProgram:_program]) {
        NSLog(@"Failed to link program: %d", _program);
        
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (_program) {
            glDeleteProgram(_program);
            _program = 0;
        }
        
        return NO;
    }
    
    // Get uniform locations.
    uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX] = glGetUniformLocation(_program, "modelViewProjectionMatrix");
    uniforms[UNIFORM_NORMAL_MATRIX] = glGetUniformLocation(_program, "normalMatrix");
    uniforms[UNIFORM_MODELVIEW_MATRIX] = glGetUniformLocation(_program, "modelViewMatrix");
    uniforms[UNIFORM_TEXTURE] = glGetUniformLocation(_program, "texture");
    uniforms[UNIFORM_FLASHLIGHT_POSITION] = glGetUniformLocation(_program, "flashlightPosition");
    uniforms[UNIFORM_DIFFUSE_LIGHT_POSITION] = glGetUniformLocation(_program, "diffuseLightPosition");
    uniforms[UNIFORM_SHININESS] = glGetUniformLocation(_program, "shininess");
    uniforms[UNIFORM_AMBIENT_COMPONENT] = glGetUniformLocation(_program, "ambientComponent");
    uniforms[UNIFORM_DIFFUSE_COMPONENT] = glGetUniformLocation(_program, "diffuseComponent");
    uniforms[UNIFORM_SPECULAR_COMPONENT] = glGetUniformLocation(_program, "specularComponent");
    uniforms[UNIFORM_FOG_DENSITY] = glGetUniformLocation(_program, "fogDensity");
    
    glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
    
    // Release vertex and fragment shaders.
    if (vertShader) {
        glDetachShader(_program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(_program, fragShader);
        glDeleteShader(fragShader);
    }
    
    return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source) {
        NSLog(@"Failed to load vertex shader");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

#pragma mark - Utility functions

// Load in and set up texture image (adapted from Ray Wenderlich)
- (GLuint)setupTexture:(NSString *)fileName
{
    CGImageRef spriteImage = [UIImage imageNamed:fileName].CGImage;
    if (!spriteImage) {
        NSLog(@"Failed to load image %@", fileName);
        exit(1);
    }
    
    size_t width = CGImageGetWidth(spriteImage);
    size_t height = CGImageGetHeight(spriteImage);
    
    GLubyte *spriteData = (GLubyte *) calloc(width*height*4, sizeof(GLubyte));
    
    CGContextRef spriteContext = CGBitmapContextCreate(spriteData, width, height, 8, width*4, CGImageGetColorSpace(spriteImage), kCGImageAlphaPremultipliedLast);
    
    CGContextDrawImage(spriteContext, CGRectMake(0, 0, width, height), spriteImage);
    
    CGContextRelease(spriteContext);
    
    GLuint texName;
    glGenTextures(1, &texName);
    glBindTexture(GL_TEXTURE_2D, texName);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, spriteData);
    
    free(spriteData);
    return texName;
}

- (IBAction)toggleFog:(id)sender {
    fogOn = !fogOn;
}

- (IBAction)toggleDayNight:(id)sender {
    nightOn = !nightOn;
}

- (IBAction)toggleFlashLight:(id)sender {
    flashLightOn = !flashLightOn;
}

- (IBAction)toggleModelMovement:(id)sender {
    modelMoving = !modelMoving;
}

- (IBAction)moveModel:(UIPanGestureRecognizer *)sender {
    if(!modelMoving && canControl){
        CGPoint p = [sender translationInView:self.view];
        modelPosition.x += p.x * 0.00005;
        if(sender.numberOfTouches == 2){
            modelPosition.z += p.y * 0.00005;
        }else{
            modelPosition.y += p.y * 0.00005;
        }
    }
}

-(IBAction)scaleModel:(UIPinchGestureRecognizer* )sender{
    if(!modelMoving && canControl){
        float scale = 0;
        if(sender.scale < 1){
            scale = 1/sender.scale;
            modelScale -= scale * 0.001f;
        }else{
            scale = sender.scale;
            modelScale += scale * 0.001f;
        }
    }
    
}

-(IBAction)rotateModel:(UIRotationGestureRecognizer* )sender{
    if(!modelMoving && canControl){
        modelRotation += sender.rotation * 0.1f;
    }
}
- (IBAction)resetModelPos:(id)sender {
    modelPosition = GLKVector3Make(0, 0, -1);
    modelScale = 0.05f;
    modelRotation = 0;
}

-(void)updateModelPosition{
    if(modelPosition.x >= 3){
        deltaX = -0.01;
    }
    if(modelPosition.x <= 0){
        deltaX = 0.01;
    }
    
    if(modelPosition.z >= 0){
        deltaZ = -0.01;
    }
    if(modelPosition.z <= -3){
        deltaZ = 0.01;
    }
    
    modelPosition.x += deltaX;
    modelPosition.z += deltaZ;
}

-(BOOL)sameCell:(GLKVector3)obj1 : (GLKVector3)obj2{
    // Hack to fix coordinate system
    GLKVector3 flipped = GLKVector3Make(obj2.x * -1, obj2.y, obj2.z * -1);
    float distance = GLKVector2Distance(GLKVector2Make(obj1.x, obj1.z), GLKVector2Make(flipped.x, flipped.z));
    return distance < 2;
}


-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer{
    return true;
}

@end

