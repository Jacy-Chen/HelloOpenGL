//
//  OpenGLView.m
//  HelloOpenGL
//
//  Created by Zexi Chen on 7/5/16.
//  Copyright © 2016 Jacy Chen. All rights reserved.
//

#import "OpenGLView.h"
#import "CC3GLMatrix.h"

//structure for vertexs
typedef struct {
    float Position[3];
    float Color[4];
} Vertex;

////Four vertex structure, which will be used to make triangles
//const Vertex Vertices[] = {
//    {{1, -1, 0}, {1, 0, 0, 1}},
//    {{1, 1, 0}, {0, 1, 0, 1}},
//    {{-1, 1, 0}, {0, 0, 1, 1}},
//    {{-1, -1, 0}, {0, 0, 0, 1}}
//};

// Modify vertices so they are within projection near/far planes
const Vertex Vertices[] = {
    {{1, -1, -7}, {1, 0, 0, 1}},
    {{1, 1, -7}, {0, 1, 0, 1}},
    {{-1, 1, -7}, {0, 0, 1, 1}},
    {{-1, -1, -7}, {0, 0, 0, 1}}
};

//Two triangles with their vertex
const GLubyte Indices[] = {
    0, 1, 2,
    2, 3, 0
};



@implementation OpenGLView


#pragma mark UIView Life cycle
// init mehtod override
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setupLayer];
        [self setupContext];
        
        [self setupRenderBuffer];
        [self setupFrameBuffer];
        
        //call openGL on the run
        [self compileShaders];
        [self setupVBOs];
        
        //render and show the render result
        [self render];
        
        
    }
    return self;
}

// Replace dealloc method with this
- (void)dealloc
{
    _context = nil;
}

+ (Class)layerClass {
    return [CAEAGLLayer class];
}


#pragma mark UIView CALayer + GLLayer setup method
- (void)setupLayer {
    //CAEAGLLayer is the subclass of the CALayer
    _eaglLayer = (CAEAGLLayer*) self.layer;
    _eaglLayer.opaque = YES;
}

- (void)setupContext {
    //Setup openGl Context for render purpose
    EAGLRenderingAPI api = kEAGLRenderingAPIOpenGLES2;
    _context = [[EAGLContext alloc] initWithAPI:api];
    
    if (!_context) {
        NSLog(@"Failed to initialize OpenGLES 2.0 context");
        exit(1);
    }
    
    if (![EAGLContext setCurrentContext:_context]) {
        NSLog(@"Failed to set current OpenGL context");
        exit(1);
    }
}

- (void)setupRenderBuffer {
    //Render buffer is openGL object to save the rendered image to present
    glGenRenderbuffers(1, &_colorRenderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _colorRenderBuffer);
    
    //Attach a render buffer to EAGL drawable
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:_eaglLayer];
}


- (void)setupFrameBuffer {
    //Frame Buffer is openGL object that contain a render buffer
    //others:
    //-- depth buffer, stencil buffer, accumulation buffer
    GLuint framebuffer;
    glGenFramebuffers(1, &framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    //Attach a renderbuffer object to a framebuffer object
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                              GL_RENDERBUFFER, _colorRenderBuffer);
}

#pragma mark - OpenGL runtime compiling and linking methods

//class method to compile shader
- (void)compileShaders {
    // 1: shader code file information --> compile two shaders code at the runtime
    GLuint vertexShader = [self compileShader:@"SimpleVertex"
                                     withType:GL_VERTEX_SHADER];
    GLuint fragmentShader = [self compileShader:@"SimpleFragment"
                                       withType:GL_FRAGMENT_SHADER];
    
    // 2: Create the program --> link the vertex and fragment shader into a complete program
    GLuint programHandle = glCreateProgram();
    
    //attach the shader into the program
    glAttachShader(programHandle, vertexShader);
    glAttachShader(programHandle, fragmentShader);
    
    //link all the shaders within the program
    glLinkProgram(programHandle);
    
    // 3: link infomation
    GLint linkSuccess;
    glGetProgramiv(programHandle, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        //get the information of link information
        GLchar messages[256];
        glGetProgramInfoLog(programHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }
    
    // 4: let openGL to use this program (compiled on the run)
    glUseProgram(programHandle);
    
    // 5: get a pointer to the output paramters
    _positionSlot = glGetAttribLocation(programHandle, "Position");
    _colorSlot = glGetAttribLocation(programHandle, "SourceColor");
    glEnableVertexAttribArray(_positionSlot);
    glEnableVertexAttribArray(_colorSlot);
    
    
    // Add to bottom of compileShaders
    _projectionUniform = glGetUniformLocation(programHandle, "Projection");
}


//Method to compile Shader at the runtime with shader type and name
- (GLuint)compileShader:(NSString*)shaderName withType:(GLenum)shaderType {
    // 1 Find the file in the xcode bundle
    NSString* shaderPath = [[NSBundle mainBundle] pathForResource:shaderName
                                                           ofType:@"glsl"];
    NSError* error;
    //czx:: get the code content in the file
    NSString* shaderString = [NSString stringWithContentsOfFile:shaderPath
                                                       encoding:NSUTF8StringEncoding error:&error];
    //check if we get the code content
    if (!shaderString) {
        NSLog(@"Error loading shader: %@", error.localizedDescription);
        exit(1);
    }
    
    // 2 create the shader according to input type
    GLuint shaderHandle = glCreateShader(shaderType);
    
    // 3 content --> C style
    const char * shaderStringUTF8 = [shaderString UTF8String];
    int shaderStringLength = [shaderString length];
    
    //To give the openGL the shader's source code (which we got from glCreateShader)
    glShaderSource(shaderHandle, 1, &shaderStringUTF8, &shaderStringLength);
    
    // 4 compile the shader souce code at the run time
    glCompileShader(shaderHandle);
    
    // 5 start to compile the shader souce code
    GLint compileSuccess;
    glGetShaderiv(shaderHandle, GL_COMPILE_STATUS, &compileSuccess);
    if (compileSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(shaderHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }
    
    return shaderHandle;
    
}

#pragma mark - Input Paramerters to openGL program
//method for the vertex buffer objects
- (void)setupVBOs {
    //Setup the vertex and indices
    //Buffer objects --> should be familiar with it
    GLuint vertexBuffer;
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(Vertices), Vertices, GL_STATIC_DRAW);
    
    GLuint indexBuffer;
    glGenBuffers(1, &indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(Indices), Indices, GL_STATIC_DRAW);
    
}

#pragma mark - Render result output method 

- (void)render {
    //clear the screen color with the color here specified
    glClearColor(0, 104.0/255.0, 55.0/255.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    
    // Add to render, right before the call to glViewport
    CC3GLMatrix *projection = [CC3GLMatrix matrix];
    float h = 4.0f * self.frame.size.height / self.frame.size.width;
    [projection populateFromFrustumLeft:-2 andRight:2 andBottom:-h/2 andTop:h/2 andNear:4 andFar:10];
    glUniformMatrix4fv(_projectionUniform, 1, 0, projection.glMatrix);
    
    
    // 1 set the portion of the UIView to use for rendering
    glViewport(0, 0, self.frame.size.width, self.frame.size.height);
    
    // 2 feed the correct values to the two inpue variables for the vertex shader
    // -->Position
    // -->SourceColor
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE,
                          sizeof(Vertex), 0);
    //Final Parameter:
    //The offset within the struct
    glVertexAttribPointer(_colorSlot, 4, GL_FLOAT, GL_FALSE,
                          sizeof(Vertex), (GLvoid*) (sizeof(float) * 3));
    
    // 3 To Call Vertex shaders --> then Fragment shaders
    // (1) triangle is the most popular way
    // (2) vertices of the the reder -- C style
    // (3) data type of each individual index
    // (4) Should be pointer to the indices
    glDrawElements(GL_TRIANGLES, sizeof(Indices)/sizeof(Indices[0]),
                   GL_UNSIGNED_BYTE, 0);
    
    // Presenct the rendered Buffer on the view
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}




@end
