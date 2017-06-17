//
//  KSYPlotCircularBuffer.h
//  EditDemo
//
//  Created by sunyazhou on 2017/6/16.
//  Copyright © 2017年 Kingsoft, Inc. All rights reserved.
//

#ifndef KSYPlotCircularBuffer_h
#define KSYPlotCircularBuffer_h

#include <libkern/OSAtomic.h>
#include <string.h>
#include <assert.h>

#ifdef __cplusplus
extern "C" {
#endif
    
    typedef struct {
        void             *buffer;
        int32_t           length;
        int32_t           tail;
        int32_t           head;
        volatile int32_t  fillCount;
        bool              atomic;
    } KSYPlotCircularBuffer;
    
    /*!
     * Initialise buffer
     *
     *  Note that the length is advisory only: Because of the way the
     *  memory mirroring technique works, the true buffer length will
     *  be multiples of the device page size (e.g. 4096 bytes)
     *
     * @param buffer Circular buffer
     * @param length Length of buffer
     */
#define KSYPlotCircularBufferInit(buffer, length) \
_KSYPlotCircularBufferInit(buffer, length, sizeof(*buffer))
    bool _KSYPlotCircularBufferInit(KSYPlotCircularBuffer *buffer, int32_t length, size_t structSize);
    
    /*!
     * Cleanup buffer
     *
     *  Releases buffer resources.
     */
    void  KSYPlotCircularBufferCleanup(KSYPlotCircularBuffer *buffer);
    
    /*!
     * Clear buffer
     *
     *  Resets buffer to original, empty state.
     *
     *  This is safe for use by consumer while producer is accessing
     *  buffer.
     */
    void  KSYPlotCircularBufferClear(KSYPlotCircularBuffer *buffer);
    
    /*!
     * Set the atomicity
     *
     *  If you set the atomiticy to false using this method, the buffer will
     *  not use atomic operations. This can be used to give the compiler a little
     *  more optimisation opportunities when the buffer is only used on one thread.
     *
     *  Important note: Only set this to false if you know what you're doing!
     *
     *  The default value is true (the buffer will use atomic operations)
     *
     * @param buffer Circular buffer
     * @param atomic Whether the buffer is atomic (default true)
     */
    void  KSYPlotCircularBufferSetAtomic(KSYPlotCircularBuffer *buffer, bool atomic);
    
    // Reading (consuming)
    
    /*!
     * Access end of buffer
     *
     *  This gives you a pointer to the end of the buffer, ready
     *  for reading, and the number of available bytes to read.
     *
     * @param buffer Circular buffer
     * @param availableBytes On ouKSYPlotut, the number of bytes ready for reading
     * @return Pointer to the first bytes ready for reading, or NULL if buffer is empty
     */
    static __inline__ __attribute__((always_inline)) void* KSYPlotCircularBufferTail(KSYPlotCircularBuffer *buffer, int32_t* availableBytes) {
        *availableBytes = buffer->fillCount;
        if ( *availableBytes == 0 ) return NULL;
        return (void*)((char*)buffer->buffer + buffer->tail);
    }
    
    /*!
     * Consume bytes in buffer
     *
     *  This frees up the just-read bytes, ready for writing again.
     *
     * @param buffer Circular buffer
     * @param amount Number of bytes to consume
     */
    static __inline__ __attribute__((always_inline)) void KSYPlotCircularBufferConsume(KSYPlotCircularBuffer *buffer, int32_t amount) {
        buffer->tail = (buffer->tail + amount) % buffer->length;
        if ( buffer->atomic ) {
            OSAtomicAdd32Barrier(-amount, &buffer->fillCount);
        } else {
            buffer->fillCount -= amount;
        }
        assert(buffer->fillCount >= 0);
    }
    
    /*!
     * Access front of buffer
     *
     *  This gives you a pointer to the front of the buffer, ready
     *  for writing, and the number of available bytes to write.
     *
     * @param buffer Circular buffer
     * @param availableBytes On ouKSYPlotut, the number of bytes ready for writing
     * @return Pointer to the first bytes ready for writing, or NULL if buffer is full
     */
    static __inline__ __attribute__((always_inline)) void* KSYPlotCircularBufferHead(KSYPlotCircularBuffer *buffer, int32_t* availableBytes) {
        *availableBytes = (buffer->length - buffer->fillCount);
        if ( *availableBytes == 0 ) return NULL;
        return (void*)((char*)buffer->buffer + buffer->head);
    }
    
    // Writing (producing)
    
    /*!
     * Produce bytes in buffer
     *
     *  This marks the given section of the buffer ready for reading.
     *
     * @param buffer Circular buffer
     * @param amount Number of bytes to produce
     */
    static __inline__ __attribute__((always_inline)) void KSYPlotCircularBufferProduce(KSYPlotCircularBuffer *buffer, int32_t amount) {
        buffer->head = (buffer->head + amount) % buffer->length;
        if ( buffer->atomic ) {
            OSAtomicAdd32Barrier(amount, &buffer->fillCount);
        } else {
            buffer->fillCount += amount;
        }
        assert(buffer->fillCount <= buffer->length);
    }
    
    /*!
     * Helper routine to copy bytes to buffer
     *
     *  This copies the given bytes to the buffer, and marks them ready for reading.
     *
     * @param buffer Circular buffer
     * @param src Source buffer
     * @param len Number of bytes in source buffer
     * @return true if bytes copied, false if there was insufficient space
     */
    static __inline__ __attribute__((always_inline)) bool KSYPlotCircularBufferProduceBytes(KSYPlotCircularBuffer *buffer, const void* src, int32_t len) {
        int32_t space;
        void *ptr = KSYPlotCircularBufferHead(buffer, &space);
        if ( space < len ) return false;
        memcpy(ptr, src, len);
        KSYPlotCircularBufferProduce(buffer, len);
        return true;
    }
    
    /*!
     * Deprecated method
     */
    static __inline__ __attribute__((always_inline)) __deprecated_msg("use KSYPlotCircularBufferSetAtomic(false) and KSYPlotCircularBufferConsume instead")
    void KSYPlotCircularBufferConsumeNoBarrier(KSYPlotCircularBuffer *buffer, int32_t amount) {
        buffer->tail = (buffer->tail + amount) % buffer->length;
        buffer->fillCount -= amount;
        assert(buffer->fillCount >= 0);
    }
    
    /*!
     * Deprecated method
     */
    static __inline__ __attribute__((always_inline)) __deprecated_msg("use KSYPlotCircularBufferSetAtomic(false) and KSYPlotCircularBufferProduce instead")
    void KSYPlotCircularBufferProduceNoBarrier(KSYPlotCircularBuffer *buffer, int32_t amount) {
        buffer->head = (buffer->head + amount) % buffer->length;
        buffer->fillCount += amount;
        assert(buffer->fillCount <= buffer->length);
    }
    
#ifdef __cplusplus
}
#endif


#endif /* KSYPlotCircularBuffer_h */
