// Copyright 2015-present 650 Industries. All rights reserved.

package abi6_0_0.host.exp.exponent;

import abi6_0_0.com.facebook.react.ReactPackage;
import abi6_0_0.com.facebook.react.animated.NativeAnimatedModule;
import abi6_0_0.com.facebook.react.bridge.JavaScriptModule;
import abi6_0_0.com.facebook.react.bridge.NativeModule;
import abi6_0_0.com.facebook.react.bridge.ReactApplicationContext;
import abi6_0_0.com.facebook.react.uimanager.ViewManager;

import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.Map;

import host.exp.exponent.ExponentManifest;
import abi6_0_0.host.exp.exponent.modules.api.CryptoModule;
import abi6_0_0.host.exp.exponent.modules.api.FabricModule;
import abi6_0_0.host.exp.exponent.modules.api.FacebookModule;
import abi6_0_0.host.exp.exponent.modules.api.URLHandlerModule;
import abi6_0_0.host.exp.exponent.modules.api.ConstantsModule;
import abi6_0_0.host.exp.exponent.modules.api.ContactsModule;
import abi6_0_0.host.exp.exponent.modules.api.FontLoaderModule;
import abi6_0_0.host.exp.exponent.modules.api.ImageCropperModule;
import abi6_0_0.host.exp.exponent.modules.api.KeyboardModule;
import abi6_0_0.host.exp.exponent.modules.api.LocationModule;
import abi6_0_0.host.exp.exponent.modules.api.NotificationsModule;
import abi6_0_0.host.exp.exponent.modules.api.ShakeModule;
import abi6_0_0.host.exp.exponent.modules.api.UtilModule;
import abi6_0_0.host.exp.exponent.modules.api.ImagePickerModule;
import abi6_0_0.host.exp.exponent.modules.api.filesystem.FileSystemModule;
import abi6_0_0.host.exp.exponent.modules.internal.ExponentAsyncStorageModule;
import abi6_0_0.host.exp.exponent.modules.internal.ExponentUnsignedAsyncStorageModule;

public class ExponentPackage implements ReactPackage {

  private final boolean mIsKernel;
  private final Map<String, Object> mExperienceProperties;
  private final JSONObject mManifest;

  public ExponentPackage(Map<String, Object> experienceProperties, JSONObject manifest) {
    mIsKernel = false;
    mExperienceProperties = experienceProperties;
    mManifest = manifest;
  }

  public ExponentPackage() {
    mIsKernel = true;
    mExperienceProperties = null;
    mManifest = new JSONObject();
  }

  @Override
  public List<NativeModule> createNativeModules(ReactApplicationContext reactContext) {
    boolean isVerified = false;
    if (mManifest != null) {
      isVerified = mManifest.optBoolean(ExponentManifest.MANIFEST_IS_VERIFIED_KEY);
    }

    List<NativeModule> nativeModules = new ArrayList<>(Arrays.<NativeModule>asList(
        new URLHandlerModule(reactContext),
        new ConstantsModule(reactContext, mExperienceProperties, mManifest),
        new ShakeModule(reactContext),
        new FontLoaderModule(reactContext, mManifest),
        new KeyboardModule(reactContext),
        new UtilModule(reactContext),
        new NativeAnimatedModule(reactContext)
    ));

    if (mIsKernel) {
      //nativeModules.add(new ExponentKernelModule(reactContext, mApplication));
    } else {
      if (isVerified) {
        nativeModules.add(new ExponentAsyncStorageModule(reactContext, mManifest));
        nativeModules.add(new NotificationsModule(reactContext, mManifest));
        nativeModules.add(new ContactsModule(reactContext));
        nativeModules.add(new FileSystemModule(reactContext, mManifest));
        nativeModules.add(new LocationModule(reactContext));
        nativeModules.add(new CryptoModule(reactContext));
        nativeModules.add(new ImagePickerModule(reactContext));
        nativeModules.add(new FacebookModule(reactContext));
        nativeModules.add(new FabricModule(reactContext, mExperienceProperties));
      } else {
        nativeModules.add(new ExponentUnsignedAsyncStorageModule(reactContext));
      }
      nativeModules.add(new ImageCropperModule(reactContext));
    }

    return nativeModules;
  }

  @Override
  public List<Class<? extends JavaScriptModule>> createJSModules() {
    return Collections.emptyList();
  }

  @Override
  public List<ViewManager> createViewManagers(ReactApplicationContext reactContext) {
    return Collections.emptyList();
  }
}
