#import <metal_stdlib>
using namespace metal;


typedef atomic_uint visbin;

uint ldbin(uint nlgt);
uint ldbin(threadgroup visbin &bin);
uint ldbin(threadgroup visbin *bins, xcamera cam, float z);
