/*
 * ===========================================================================
 (C) Copyright Sun Microsystems Inc, 1992, 2004. All rights reserved.
 * ===========================================================================
 */




/* 
 *
 * Change activity:
 *
 * Reason  Date   Origin  Description
 * ------  ----   ------  ---------------------------------------------------- 
 * 003677  261099 hdbabt: Original creation
 * 051150  240502 slattery New method for getting a zip class
 *
 * ===========================================================================
 * Module Information:
 *		
 * DESCRIPTION: Native functions for LocalizedInputStream class.
 * ===========================================================================
 */

/*
 * ======================================================================
 * Required includes
 * ======================================================================
 */
#include <string.h>
#include <stdlib.h>
#include <jvm.h>
#include <jni.h>

/*
 * ======================================================================
 * Internal Definitions
 * ======================================================================
 */

/*
 * ======================================================================
 * External Data Declarations
 * ======================================================================
 */

/*
 * ======================================================================
 * Internal Data Declarations
 * ======================================================================
 */

/*
 * ======================================================================
 * Internal Functions Declarations
 * ======================================================================
 */

/*****************************************************************************
 *Function Name  : Java_com_ibm_jvm_io_LocalizedInputStream_unwrap
 *
 *Parameters     : inputStream This is a FilterInputStream containing an
 *                             input stream.
 *
 *Description    : Extract, from a FilterInputStream, the hidden input stream
 *                 Added as part of Feature ibm@1258
 *
 *Returns        : An input stream.
 *
 ******************************************************************************
 */
JNIEXPORT jobject JNICALL
Java_com_ibm_jvm_io_LocalizedInputStream_unwrap(JNIEnv * env,
                                                jclass this,
                                                jobject inputStream)
{
    jclass   c = (*env)->GetObjectClass(env, inputStream);
    jfieldID f = (*env)->GetFieldID(env, c, "in", "Ljava/io/InputStream;");

    return (*env)->GetObjectField(env, inputStream, f);
}
/* END OF FILE */