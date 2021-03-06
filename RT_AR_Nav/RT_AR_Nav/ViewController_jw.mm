//
//  ViewController.m
//  RT_AR_Nav
//
//  Created by Johnny Wang on 12/1/15.
//  Copyright © 2015 CV_Apps. All rights reserved.
//

#include "opencv2/opencv.hpp"
#import "ViewController.h"  // this HAS TO come before homographyUtil
#include "homographyUtil.hpp"

#import <GPUImage/GPUImage.h>



//#define USE_OPENCV

@interface ViewController () {
    AVPlayer *player_;

#ifdef USE_OPENCV
    UIImageView *imageView_;
#else
    GPUImageView *imageView;
#endif
    
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
//    [self playVideo];
    
    [self loadVideo];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)playVideo {
    NSString *filepath = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"mp4"];
    NSURL *fileURL = [NSURL fileURLWithPath:filepath];
    self->player_ = [AVPlayer playerWithURL:fileURL];
    
    AVPlayerLayer *layer = [AVPlayerLayer playerLayerWithPlayer:self->player_];
    self->player_.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    layer.frame = CGRectMake(0, 0, 1024, 768);
    [self.view.layer addSublayer: layer];
    
    [self->player_ play];
}

- (void)loadVideo {
    NSString *filepath = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"mp4"];
    NSURL *fileURL = [NSURL fileURLWithPath:filepath];
    
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:fileURL options:nil];
    AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    gen.appliesPreferredTrackTransform = YES;
    
#ifdef USE_OPENCV
    imageView_ = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, 0.0, self.view.frame.size.width, self.view.frame.size.height)];
    [self.view addSubview:imageView_];
    imageView_.contentMode = UIViewContentModeScaleAspectFit;
#else
    imageView = [[GPUImageView alloc] initWithFrame:CGRectMake(0.0, 0.0, self.view.frame.size.width, self.view.frame.size.height)];
    // Important: add as a subview
    [self.view addSubview:imageView];
#endif

    // Display 10 frames per second
    CMTime vid_length = asset.duration;
    float seconds = CMTimeGetSeconds(vid_length);
    
    int required_frames_count = seconds * 10;
    int64_t step = vid_length.value / required_frames_count;
    
    int value = 0;
    
    //for (int i = 0; required_frames_count; i++) {
    for (int i = 0; i<1; ++i){//required_frames_count; i++) {
            
        AVAssetImageGenerator *image_generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
        image_generator.requestedTimeToleranceAfter = kCMTimeZero;
        image_generator.requestedTimeToleranceBefore = kCMTimeZero;
        
        CMTime time = CMTimeMake(value, vid_length.timescale);
        
        CGImageRef image_ref = [image_generator copyCGImageAtTime:time actualTime:NULL error:NULL];
        UIImage *thumb = [UIImage imageWithCGImage:image_ref];
        CGImageRelease(image_ref);
        NSString *filename = [NSString stringWithFormat:@"frame_%d.png", i];
        NSString *pngPath = [NSHomeDirectory() stringByAppendingPathComponent:filename];
        
        [UIImagePNGRepresentation(thumb) writeToFile:pngPath atomically:YES];
        

#ifdef USE_OPENCV
        imageView_.image = [self processImage:thumb];
//        imageView_.image = thumb;
#else
        [self processImage:thumb];
//        GPUImageHoughTransformLineDetector *retImg = [self processImage:thumb];
//        [retImg addTarget:imageView];
#endif
        
        value += step;
        
        NSLog(@"%d: %@", value, pngPath);
    }
}


#ifdef USE_OPENCV
- (UIImage *)processImage:(UIImage *)inputImage
#else
- (void) processImage:(UIImage *)inputImage
#endif
{
    inputImage = [UIImage imageNamed:@"forbes.jpg"];
    
#ifdef USE_OPENCV
    Mat roadImage = [self cvMatFromUIImage:inputImage];
#else
    GPUImagePicture *roadImage = [[GPUImagePicture alloc] initWithImage:inputImage];
#endif
    
    double t = (double)getTickCount();
    
    // convert the road name to a image
    Mat textImage = cvMatFromString_cv("FORBES");
    UIImage *textUIImage = [self UIImageFromCVMat:textImage];
    GPUImagePicture *textGPUImage = [[GPUImagePicture alloc] initWithImage:textUIImage];
    
    // Initialize road name boundary points
    // [TODO] Automate this
    vector<Point2f> pts_from={Point2f(0,0),Point2f(0,textImage.rows),Point2f(textImage.cols,0),Point2f(textImage.cols,textImage.rows)};
    vector<Point2f> pts_to={Point2f(500,456),Point2f(392,522),Point2f(805,450),Point2f(840,517)};
    
    // Test code for boundary estimation
    
    
#ifdef USE_OPENCV
    Mat roadImageGray;
    cvtColor(roadImage, roadImageGray, CV_BGR2GRAY);
    
    cv::Rect roi(roadImageGray.cols/2-200,roadImageGray.rows/2, 400, roadImageGray.rows/2);
    Mat roadImageGaussian=roadImageGray(roi);

//    Mat roadImageGaussian;
//    Mat roadImageGray;
//    cvtColor(roadImage, roadImageGray, CV_BGR2GRAY);
//    cvtColor(roadImage, roadImageGaussian, CV_BGR2GRAY);

    vector<Vec2f> lines;
    
    //Mat roadImageGray;
    GaussianBlur(roadImageGaussian, roadImageGaussian, cv::Size(15,15), 5);
    
    resize(roadImageGaussian,roadImageGaussian,cv::Size(),0.5,0.5);
    
    Canny(roadImageGaussian, roadImageGaussian, 0, 50, 3);
    
    resize(roadImageGaussian,roadImageGaussian,cv::Size(),2,2,INTER_CUBIC);
    
    HoughLines(roadImageGaussian, lines, 1, CV_PI/180, 200, 0, 0 );
    
    cvtColor(roadImageGaussian, roadImageGaussian, CV_GRAY2BGR);
    
        vector<float> angle_range(180/5,0);
        vector<float> r_range(180/5,0);
    
        for( size_t i = 0; i < lines.size(); i++ )
        {
            float rho = lines[i][0], theta = lines[i][1];
            if(abs(abs(theta)-CV_PI/2)>CV_PI/18)
            {
    
                size_t ind=floor((theta)/(CV_PI/36));
                cout<<ind<<endl;
                angle_range[ind]=theta;
                r_range[ind]=rho;
            }
        }
    
    
        float left_most_line_rho=0.0f;;
        float left_most_line_theta=0.0f;
        float right_most_line_rho=0.0f;
        float right_most_line_theta=0.0f;
    
        for(size_t i=8; i<36-7;++i)
        {
            if(angle_range[i]!=0)
            {
                left_most_line_rho=r_range[i];
                left_most_line_theta=angle_range[i];
                break;
            }
        }
    
    
        for(int i=36-7; i>=8;--i)
        {
            if(angle_range[i]!=0)
            {
                right_most_line_rho=r_range[i];
                right_most_line_theta=angle_range[i];
                break;
            }
        }
    
    
        vector<Vec2f> lines_filtered;
        if(right_most_line_rho==left_most_line_rho)
            cout<<"no plane detected"<<endl;
        else
        {
            lines_filtered.push_back(Vec2f(left_most_line_rho,left_most_line_theta));
            lines_filtered.push_back(Vec2f(right_most_line_rho,right_most_line_theta));
        }
    
    
        vector<Point2f> pt_to;
    
        for( size_t i = 0; i < lines_filtered.size(); i++ )
        {
            float rho = lines_filtered[i][0], theta = lines_filtered[i][1];
            cv::Point pt1, pt2;
            double a = cos(theta), b = sin(theta);
            double x0 = a*rho, y0 = b*rho;
            pt1.x = cvRound(x0 + 3000*(-b))+roadImageGray.cols/2-200;
            pt1.y = cvRound(y0 + 3000*(a))+roadImageGray.rows/2;
            pt2.x = cvRound(x0 - 3000*(-b))+roadImageGray.cols/2-200;
            pt2.y = cvRound(y0 - 3000*(a))+roadImageGray.rows/2;
    
            //calculate the pt_to
    
            float _y1 = 5*roadImage.rows/6;
            float _y2 = roadImage.rows;
    
            float _ratio = ((float)pt1.x-(float)pt2.x)/((float)pt1.y-(float)pt2.y);
    
            float _x1 = pt1.x-((pt1.y-_y1)*_ratio);
            float _x2 = pt1.x-((pt1.y-_y2)*_ratio);
    
    
    
            cout<<_x1<<" "<<_y1<<" "<<_x2<<" "<<_y2<<endl;
            pt_to.push_back(Point2f(_x1,_y1));
            pt_to.push_back(Point2f(_x2,_y2));
    
            //line( roadImage, pt1, pt2, Scalar(0,0,255), 3, CV_AA);
        }
    
        cout<<lines_filtered.size()<<endl;
    
        // Find homography
        Mat H;
        fitHomography(pts_from, pt_to, H);
        cout<<H<<endl;
    
        // Project the warped road name
        Mat resultImage;
        projHomography(roadImage, textImage, resultImage, H);
    
        t = ((double)getTickCount() - t)/getTickFrequency();
        cout<<"Time: "<<t<<"s"<<endl;
    
        // Display the image
        imageView_ = [[UIImageView alloc] initWithFrame:CGRectMake(0.0, 0.0, self.view.frame.size.width, self.view.frame.size.height)];
        [self.view addSubview:imageView_];
        imageView_.contentMode = UIViewContentModeScaleAspectFit;
        
        //   imageView_.image = [self UIImageFromCVMat:resultImage];
        UIImage *ret_img = [self UIImageFromCVMat:resultImage];
        return ret_img;
    
#else
    
    GPUImageGrayscaleFilter *roadImageGray_ = [[GPUImageGrayscaleFilter alloc] init];
    [roadImage addTarget:roadImageGray_];
    
    // set ROI here
    // roadImageGray --> roadImageGrayROI
    // change var name below
    
//    GPUImageCropFilter *roadImageGray = [[GPUImageCropFilter alloc] initWithCropRegion:CGRectMake(roadImage./2-200,roadImage.rows/2, 400, roadImage.rows/2)];
    GPUImageCropFilter *roadImageGray = [[GPUImageCropFilter alloc] initWithCropRegion:CGRectMake(100,100,100,100)];
    [roadImageGray_ addTarget:roadImageGray];
    
    GPUImageGaussianBlurFilter *roadImageGaussian = [[GPUImageGaussianBlurFilter alloc] init];
    roadImageGaussian.blurRadiusInPixels = 7.0;
//    roadImageGaussian.blurPasses = 5;
    [roadImageGray addTarget:roadImageGaussian];
    
    GPUImageTransformFilter *transformFilter_down = [[GPUImageTransformFilter alloc] init];
    double scale_down = 0.5;
    CGAffineTransform resizeTransform = CGAffineTransformMakeScale(scale_down, scale_down);
    transformFilter_down.affineTransform = resizeTransform;
    [roadImageGaussian addTarget:transformFilter_down];
    
    GPUImageCannyEdgeDetectionFilter *cannyFilter = [[GPUImageCannyEdgeDetectionFilter alloc] init];
//    cannyFilter.lowerThreshold = 0;
//    cannyFilter.upperThreshold = 50;
    [transformFilter_down addTarget:cannyFilter];
    
    
    GPUImageTransformFilter *transformFilter_up = [[GPUImageTransformFilter alloc] init];
    double scale_up = 1/scale_down;
    resizeTransform = CGAffineTransformMakeScale(scale_up, scale_up);
    transformFilter_up.affineTransform = resizeTransform;
    [cannyFilter addTarget:transformFilter_up];
    
    // add Hough transform here
    GPUImageHoughTransformLineDetector *lineFilter = [[GPUImageHoughTransformLineDetector alloc] init];
    [(GPUImageHoughTransformLineDetector *)lineFilter setLineDetectionThreshold:0.60];
    [transformFilter_up addTarget:lineFilter];
  

    // draw lines
    GPUImageLineGenerator *lineDrawFilter = [[GPUImageLineGenerator alloc] init];
    [lineDrawFilter forceProcessingAtSize:inputImage.size];
    
    __weak typeof(self) weakSelf = self;
    [lineFilter setLinesDetectedBlock:^(GLfloat *flt, NSUInteger count, CMTime time) {
        NSLog(@"Number of lines: %ld", (unsigned long)count);
        GPUImageAlphaBlendFilter *blendFilter = [[GPUImageAlphaBlendFilter alloc] init];
        [blendFilter forceProcessingAtSize:inputImage.size];
        [roadImage addTarget:blendFilter];
        [lineDrawFilter addTarget:blendFilter];
        
        [blendFilter useNextFrameForImageCapture];
        [lineDrawFilter renderLinesFromArray:flt count:count frameTime:time];
//        weakSelf.doneProcessingImage([blendFilter imageFromCurrentFramebuffer]);
    }];
    
    [lineDrawFilter addTarget:imageView];
    [roadImage processImage];
    
//    return lineFilter;
    return ;
    
#endif
    
}

- (cv::Mat)cvMatFromString:(NSString *)text
{
    /** This function is for convering the text into the cvMat format
     * There is probably a better solution to use opencv put text function
     * Not used in current code
     */
    Mat stringImage;
    return stringImage;
}

- (cv::Mat)cvMatFromUIImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels (color channels + alpha)
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to  data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    
    return cvMat;
}



// Member functions for converting from UIImage to cvMat
-(UIImage *)UIImageFromCVMat:(cv::Mat)cvMat
{
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                        cvMat.rows,                                 //height
                                        8,                                          //bits per component
                                        8 * cvMat.elemSize(),                       //bits per pixel
                                        cvMat.step[0],                            //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        kCGImageAlphaNone|kCGBitmapByteOrderDefault,// bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}

@end
