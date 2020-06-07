//
//  QViewController.m
//  001--滤镜处理
//
//  Created by Chian on 2020/4/15.
//  Copyright © 2020 CC老师. All rights reserved.
//

#import "QViewController.h"
#import <GLKit/GLKit.h>
#import "FilterBar.h"

typedef struct {
    GLKVector3 positionCoord;
    GLKVector2 textureCoord;
} SenceVertex;

@interface QViewController ()<FilterBarDelegate>
@property(strong,nonatomic) EAGLContext *context;
@property(assign,nonatomic) SenceVertex *vertices;
@property(strong,nonatomic) CAEAGLLayer *layer;
@property(assign,nonatomic) GLuint program,textureID,vertexBuffer;
@property(strong,nonatomic) CADisplayLink *displayLink;
@property(assign,nonatomic) NSInteger startTimeInterval;
@end

@implementation QViewController

- (void)dealloc
{
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
    if (_vertexBuffer) {
        glDeleteBuffers(1, &_vertexBuffer);
        _vertexBuffer = 0;
    }
    if (_vertices) {
        free(_vertices);
        _vertices = nil;
    }
}

- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    if (self.displayLink) {
        [self.displayLink  invalidate];
        self.displayLink = nil;
    }
}

-(void)viewDidLoad{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    [self setupFilterBar];
    [self filterInit];
    [self render];
}

- (void)filterInit {
    //1.设置图层
    [self setupContext];
    //2.设置顶点数据
    [self setupVertices];
    //3.设置图层
    [self setupLayer];
    //5.绑定渲染缓存区
    [self bindRendBufferAndFrameBufferWithLayer:self.layer];
    //6.设置纹理
    [self setupTexture];
    //7.设置视口
    glViewport(0, 0, self.drawableWidth, self.drawableHeight);
    [self setupVertexBuffer];
    [self setupProgram];
    [self useProgream];
   
    
}

- (void)setupContext{
    self.context = [[EAGLContext alloc]initWithAPI:(kEAGLRenderingAPIOpenGLES2)];
    [EAGLContext setCurrentContext:self.context];
}

- (void)setupVertices{
    self.vertices = malloc(sizeof(SenceVertex) * 4);
    self.vertices[0] = (SenceVertex){{-1, 1, 0}, {0, 1}};
    self.vertices[1] = (SenceVertex){{-1, -1, 0}, {0, 0}};
    self.vertices[2] = (SenceVertex){{1, 1, 0}, {1, 1}};
    self.vertices[3] = (SenceVertex){{1, -1, 0}, {1, 0}};
}

- (void)setupLayer{
    CAEAGLLayer *lay = [[CAEAGLLayer alloc]init];
    lay.frame = CGRectMake(0, 100, CGRectGetWidth(self.view.frame), CGRectGetWidth(self.view.frame));
    lay.contentsScale = UIScreen.mainScreen.scale;
    [self.view.layer addSublayer:lay];
    self.layer = lay;
}


- (void)bindRendBufferAndFrameBufferWithLayer:(CALayer <EAGLDrawable> *)layer{
    
    GLuint renderBuffer;
    glGenRenderbuffers(1, &renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, renderBuffer);
    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:layer];

    GLuint frameBuffer;
    glGenFramebuffers(1, &frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, frameBuffer);

    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, renderBuffer);
    
}

- (void)setupTexture{
    
    NSString *imagePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"kunkun.jpg"];
    UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
    GLuint textureID = [self createTextureWithImage:image];
    self.textureID = textureID;
}
- (GLuint)createTextureWithImage:(UIImage *)image{
    
    //1、将 UIImage 转换为 CGImageRef
    CGImageRef cgImageRef = [image CGImage];
    //判断图片是否获取成功
    if (!cgImageRef) {
        NSLog(@"Failed to load image");
        exit(1);
    }
    //2、读取图片的大小，宽和高
    GLuint width = (GLuint)CGImageGetWidth(cgImageRef);
    GLuint height = (GLuint)CGImageGetHeight(cgImageRef);
    //获取图片的rect
    CGRect rect = CGRectMake(0, 0, width, height);
    
    //获取图片的颜色空间
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    //3.获取图片字节数 宽*高*4（RGBA）
    void *imageData = malloc(width * height * 4);
    //4.创建上下文
    /*
     参数1：data,指向要渲染的绘制图像的内存地址
     参数2：width,bitmap的宽度，单位为像素
     参数3：height,bitmap的高度，单位为像素
     参数4：bitPerComponent,内存中像素的每个组件的位数，比如32位RGBA，就设置为8
     参数5：bytesPerRow,bitmap的没一行的内存所占的比特数
     参数6：colorSpace,bitmap上使用的颜色空间  kCGImageAlphaPremultipliedLast：RGBA
     */
    CGContextRef context = CGBitmapContextCreate(imageData, width, height, 8, width * 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    
    //将图片翻转过来(图片默认是倒置的)
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, 1.0f, -1.0f);
    CGColorSpaceRelease(colorSpace);
    CGContextClearRect(context, rect);
    
    //对图片进行重新绘制，得到一张新的解压缩后的位图
    CGContextDrawImage(context, rect, cgImageRef);
    
    //设置图片纹理属性
    //5. 获取纹理ID
    GLuint textureID;
    glGenTextures(1, &textureID);
    glBindTexture(GL_TEXTURE_2D, textureID);
    
    //6.载入纹理2D数据
    /*
     参数1：纹理模式，GL_TEXTURE_1D、GL_TEXTURE_2D、GL_TEXTURE_3D
     参数2：加载的层次，一般设置为0
     参数3：纹理的颜色值GL_RGBA
     参数4：宽
     参数5：高
     参数6：border，边界宽度
     参数7：format
     参数8：type
     参数9：纹理数据
     */
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, imageData);
    
    //7.设置纹理属性
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    //8.绑定纹理
    /*
     参数1：纹理维度
     参数2：纹理ID,因为只有一个纹理，给0就可以了。
     */
    glBindTexture(GL_TEXTURE_2D, 0);
    
    //9.释放context,imageData
    CGContextRelease(context);
    free(imageData);
    
    //10.返回纹理ID
    return textureID;
}

- (void)setupVertexBuffer{
    GLuint vertexBuffer;
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    GLsizeiptr size = sizeof(SenceVertex) * 4;
    glBufferData(GL_ARRAY_BUFFER, size, self.vertices, GL_STATIC_DRAW);
    self.vertexBuffer = vertexBuffer;
}

- (void)render {

    //使用program
    glUseProgram(self.program);
    //绑定buffer
    glBindBuffer(GL_ARRAY_BUFFER, self.vertexBuffer);
    // 清除画布
    glClear(GL_COLOR_BUFFER_BIT);
    glClearColor(1, 1, 1, 1);
    // 重绘
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    //渲染到屏幕上
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
}

#pragma mark -FilterBar

- (void)setupFilterBar {
    CGFloat filterBarWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat filterBarHeight = 100;
    CGFloat filterBarY = [UIScreen mainScreen].bounds.size.height - filterBarHeight;
    FilterBar *filerBar = [[FilterBar alloc] initWithFrame:CGRectMake(0, filterBarY, filterBarWidth, filterBarHeight)];
    filerBar.delegate = self;
    [self.view addSubview:filerBar];
    
    NSArray *dataSource = @[@"无"];
    filerBar.itemList = dataSource;
}

- (void)filterBar:(FilterBar *)filterBar didScrollToIndex:(NSUInteger)index{
    if (index == 0) {
        [self setupProgram];
    }
    // 重新开始滤镜动画
    [self render];
}


#pragma mark-program
- (void)setupProgram{

    GLuint vshader = [self compileVertexShaderWithSource:@"Normal"];
    GLuint fshader = [self compileFragShaderWithSource:@"Normal"];
    GLuint program = glCreateProgram();
    glAttachShader(program, vshader);
    glAttachShader(program, fshader);
    glLinkProgram(program);
    
    GLint linkStatus;
    glGetProgramiv(program, GL_LINK_STATUS, &linkStatus);
    if (linkStatus == 0) {
        GLchar msg[256];
        glGetProgramInfoLog(program, sizeof(msg), 0, &msg[0]);
        NSAssert(NO, @"program link fail", msg);
        exit(1);
    }
    self.program = program;
}

- (void)useProgream{
    glUseProgram(self.program);

    GLuint positionSlot = glGetAttribLocation(self.program, "Position");
    GLuint textureSlot = glGetUniformLocation(self.program, "Texture");
    GLuint textureCoordSlot = glGetAttribLocation(self.program, "TextureCoords");

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, self.textureID);

    glUniform1f(textureSlot, 0);

    glEnableVertexAttribArray(positionSlot);
    glVertexAttribPointer(positionSlot, 3, GL_FLOAT, GL_FALSE, sizeof(SenceVertex), NULL + offsetof(SenceVertex, positionCoord));

    glEnableVertexAttribArray(textureCoordSlot);
    glVertexAttribPointer(textureCoordSlot, 2, GL_FLOAT, GL_FALSE, sizeof(SenceVertex), NULL + offsetof(SenceVertex, textureCoord));

}

- (GLuint)compileVertexShaderWithSource:(NSString *)name{
    NSString *vPath = [NSBundle.mainBundle pathForResource:name ofType:@"vsh"];
    
    NSString *vContent = [NSString stringWithContentsOfFile:vPath encoding:NSUTF8StringEncoding error:nil];
    
    GLuint vShader = glCreateShader(GL_VERTEX_SHADER);
    
    const char *vUTF8Data = vContent.UTF8String;
    int vLength = (int)vContent.length;
    
    glShaderSource(vShader, 1, &vUTF8Data, &vLength);
    glCompileShader(vShader);
    
    GLint status;
    glGetShaderiv(vShader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        GLchar message[256];
        glGetShaderInfoLog(vShader, sizeof(message), 0, &message[0]);
        NSString * msg = [NSString stringWithUTF8String:message];
        NSAssert1(NO, @"vertext shader build fail", msg);
        exit(1);
    }
    return vShader;
}


- (GLuint)compileFragShaderWithSource:(NSString *)name{
    NSString * path = [NSBundle.mainBundle pathForResource:name ofType:@"fsh"];
    NSString * content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    GLuint shader = glCreateShader(GL_FRAGMENT_SHADER);
    const char *utf8Content = content.UTF8String;
    GLint len = (GLuint)content.length;
    glShaderSource(shader, 1, &utf8Content, &len);
    glCompileShader(shader);
    
    GLint status;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        GLchar msg[256];
        glGetShaderInfoLog(shader, sizeof(msg), 0, &msg[0]);
        NSString * wo = [NSString stringWithUTF8String:msg];
        NSAssert1(NO, @"frag shader build fail", wo);
        exit(1);
    }
    return shader;
}


//获取渲染缓存区的宽
- (GLint)drawableWidth {
    GLint backingWidth;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &backingWidth);
    return backingWidth;
}
//获取渲染缓存区的高
- (GLint)drawableHeight {
    GLint backingHeight;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &backingHeight);
    return backingHeight;
}



@end
