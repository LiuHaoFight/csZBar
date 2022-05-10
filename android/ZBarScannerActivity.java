package org.cloudsky.cordovaPlugins;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.content.res.Resources;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.hardware.Camera;
import android.os.Bundle;
import android.os.Handler;
import android.os.Vibrator;
import android.util.Base64;
import android.util.Log;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.TextView;
import android.widget.Toast;


import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import com.makeramen.roundedimageview.RoundedImageView;
import net.sourceforge.zbar.ImageScanner;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.Collection;

import cn.bingoogolapple.qrcode.core.QRCodeView;
import cn.bingoogolapple.qrcode.zxing.ZXingView;



public class ZBarScannerActivity
    extends Activity implements QRCodeView.Delegate {

  // for barcode types
  private Collection<ZBarcodeFormat> mFormats = null;

  // Config ----------------------------------------------------------

  private static int autoFocusInterval =
      2000; // Interval between AFcallback and next AF attempt.

  // Public Constants ------------------------------------------------

  public static final String EXTRA_QRVALUE = "qrValue";
  public static final String EXTRA_PARAMS = "params";
  public static final int RESULT_ERROR = RESULT_FIRST_USER + 1;
  private static final int CAMERA_PERMISSION_REQUEST = 1;
  // State -----------------------------------------------------------

  private Camera camera;
  private Handler autoFocusHandler;
  private SurfaceView scannerSurface;
  private SurfaceHolder holder;
  private ImageScanner scanner;
  private int surfW, surfH;

  // Customisable stuff
  String whichCamera;
  String flashMode;

  // For retrieving R.* resources, from the actual app package
  // (we can't use actual.application.package.R.* in our code as we
  // don't know the applciation package name when writing this plugin).
  private String package_name;
  private Resources resources;

  private int blurRadius = 50;


  // Static initialisers (class) -------------------------------------

  static {
    // Needed by ZBar??
    System.loadLibrary("iconv");
  }

  // Activity Lifecycle ----------------------------------------------
  private static final String TAG = ZBarScannerActivity.class.getSimpleName();
  private static final int REQUEST_CODE_CHOOSE_QRCODE_FROM_GALLERY = 666;
  private ZXingView mZXingView;

  @Override
  public void onCreate(Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT);
    int permissionCheck = ContextCompat.checkSelfPermission(
            this.getBaseContext(), Manifest.permission.CAMERA);

    if (permissionCheck == PackageManager.PERMISSION_GRANTED) {

      initView();
      setUpCamera();

    } else {

      ActivityCompat.requestPermissions(
              this, new String[] {Manifest.permission.CAMERA},
              CAMERA_PERMISSION_REQUEST);
    }

  }

  @Override
  public void onRequestPermissionsResult(int requestCode, String permissions[],
                                         int[] grantResults) {
    switch (requestCode) {
      case CAMERA_PERMISSION_REQUEST: {
        if (grantResults.length > 0 &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED) {
          initView();
          setUpCamera();
        } else {
          onBackPressed();
        }
        return;
      }
    }
  }

  private void setUpCamera() {
    // If request is cancelled, the result arrays are empty.

    // Get parameters from JS
    Intent startIntent = getIntent();
    String paramStr = startIntent.getStringExtra(EXTRA_PARAMS);
    JSONObject params;
    try {
      params = new JSONObject(paramStr);
    } catch (JSONException e) {
      params = new JSONObject();
    }
    String textTitle = params.optString("text_title");
    String textInstructions = params.optString("text_instructions");
    Boolean drawSight = params.optBoolean("drawSight", true);
    String btnText = params.optString("btn_text");
    whichCamera = params.optString("camera");
    flashMode = params.optString("flash");
    TextView tipLabel = findViewById(getResourceId("id/centerView"));
    tipLabel.setText(textTitle);
    Button skipBtn = findViewById(getResourceId("id/skip_btn"));
    skipBtn.setText(btnText);
    skipBtn.setOnClickListener(new View.OnClickListener() {
      @Override
      public void onClick(View view) {
        onScanQRCodeSuccess("skip");
      }
    });
    if (btnText.length() > 0) {
      skipBtn.setVisibility(View.VISIBLE);
    } else {
      skipBtn.setVisibility(View.GONE);
    }
    tipLabel.setText(textTitle);
    RoundedImageView tipImage = findViewById(getResourceId("id/scanImage"));
    if (textInstructions.length() > 0) {
      Bitmap bp = stringToBitmap(textInstructions);
      tipImage.setImageBitmap(bp);
      tipImage.setVisibility(View.VISIBLE);
    } else {
      tipImage.setVisibility(View.GONE);
    }
  }


  public static Bitmap stringToBitmap(String string) {
    Bitmap bitmap = null;
    try {
      byte[] bitmapArray = Base64.decode(string.split(",")[1], Base64.DEFAULT);
      bitmap =
              BitmapFactory.decodeByteArray(bitmapArray, 0, bitmapArray.length);
    } catch (Exception e) {
      e.printStackTrace();
    }
    return bitmap;
  }

  private int getResourceId(String typeAndName) {
    if (package_name == null) {
      package_name = getApplication().getPackageName();
    }
    if (resources == null) {
      resources = getApplication().getResources();
    }
    return resources.getIdentifier(typeAndName, null, package_name);
  }

  private void initView(){
//    setContentView(R.layout.cszbarscanner);
    setContentView(getResourceId("layout/cszbarscanner"));

    mZXingView = findViewById(getResourceId("id/zxingview"));
    mZXingView.setDelegate(this);

     ImageView backButton = findViewById(getResourceId("id/backButton"));
    backButton.setOnClickListener(new View.OnClickListener() {
      @Override
      public void onClick(View v) {
        finish();
      }
    });
  }

  @Override
  protected void onStart() {
    super.onStart();

    mZXingView.startCamera(); // 打开后置摄像头开始预览，但是并未开始识别
    mZXingView.startSpotAndShowRect(); // 显示扫描框，并开始识别
  }

  @Override
  protected void onStop() {
    mZXingView.stopCamera(); // 关闭摄像头预览，并且隐藏扫描框
    super.onStop();
  }

  @Override
  protected void onDestroy() {
    mZXingView.onDestroy(); // 销毁二维码扫描控件
    super.onDestroy();
  }

  private void vibrate() {
    Vibrator vibrator = (Vibrator) getSystemService(VIBRATOR_SERVICE);
    vibrator.vibrate(200);
  }

  @Override
  public void onScanQRCodeSuccess(String result) {
    Log.e(TAG, "result:" + result);
//    setTitle("扫描结果为：" + result);
//    Toast.makeText(this, "扫描结果为:" + result, Toast.LENGTH_SHORT).show();
    Intent res = new Intent();
    res.putExtra(EXTRA_QRVALUE, result);
    setResult(Activity.RESULT_OK, res);
    vibrate();
    finish();

    //如需只扫一次 注释此方法
//    mZXingView.startSpot(); // 继续扫码识别
  }

  @Override
  public void onCameraAmbientBrightnessChanged(boolean isDark) {

  }

  @Override
  public void onScanQRCodeOpenCameraError() {
    Log.e(TAG, "打开相机出错");
    die();
  }

  // finish() due to error
  private void die() {
    setResult(RESULT_ERROR);
    finish();
  }

  // Event handlers --------------------------------------------------

  @Override
  public void onBackPressed() {
    setResult(RESULT_CANCELED);
    super.onBackPressed();
  }

}
