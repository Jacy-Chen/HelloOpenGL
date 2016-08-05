//
//  OpenGLView.h
//  HelloOpenGL
//
//  Created by Zexi Chen on 7/5/16.
//  Copyright © 2016 Jacy Chen. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <QuartzCore/QuartzCore.h>
#include <OpenGLES/ES2/gl.h>
#include <OpenGLES/ES2/glext.h>

@interface OpenGLView : UIView{
    CAEAGLLayer* _eaglLayer;
    EAGLContext* _context;
    
    GLuint _colorRenderBuffer;      //颜色渲染
    GLuint _positionSlot;           //位置
    GLuint _colorSlot;              //颜色
    GLuint _projectionUniform;      //投影位置
}

@end
