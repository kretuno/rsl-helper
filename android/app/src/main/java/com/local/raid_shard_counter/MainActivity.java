package com.local.raid_shard_counter;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
  private static final String CHANNEL = "raid_shard_counter/app_paths";

  @Override
  public void configureFlutterEngine(FlutterEngine flutterEngine) {
    super.configureFlutterEngine(flutterEngine);
    new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
        .setMethodCallHandler(
            (call, result) -> {
              if ("dataDir".equals(call.method)) {
                result.success(getFilesDir().getAbsolutePath());
              } else {
                result.notImplemented();
              }
            });
  }
}
