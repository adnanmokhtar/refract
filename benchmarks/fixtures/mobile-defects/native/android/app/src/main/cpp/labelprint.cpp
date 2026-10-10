#include <jni.h>
#include <cstdint>
#include <vector>

extern "C" JNIEXPORT jbyteArray JNICALL
Java_com_pantrygo_merchant_data_LabelPrinter_dither(JNIEnv *env, jobject, jbyteArray gray, jint width) {
    jsize n = env->GetArrayLength(gray);
    std::vector<int8_t> in(n);
    env->GetByteArrayRegion(gray, 0, n, in.data());
    std::vector<int8_t> out(n);
    for (jsize i = 0; i < n; ++i) out[i] = (static_cast<uint8_t>(in[i]) < 128) ? 1 : 0;
    jbyteArray result = env->NewByteArray(n);
    env->SetByteArrayRegion(result, 0, n, out.data());
    return result;
}
