#!/usr/bin/env python3
"""
將 WAV 檔案轉換為 單聲道 (Mono) 16-bit PCM 格式
"""

import sys
import os
from pathlib import Path

try:
    import soundfile as sf
    import numpy as np
except ImportError:
    print("❌ 需要安裝 soundfile 和 numpy")
    print("請執行: pip install soundfile numpy")
    sys.exit(1)


def convert_wav_to_mono_16bit(input_path, output_path=None, target_sample_rate=None):
    """
    將 WAV 檔案轉換為 單聲道 16-bit PCM 格式
    
    Args:
        input_path: 輸入 WAV 檔案路徑
        output_path: 輸出 WAV 檔案路徑（如果為 None，則自動命名）
        target_sample_rate: 目標取樣率（如果為 None，則保持原始取樣率）
    """
    input_path = Path(input_path)
    
    if not input_path.exists():
        print(f"❌ 找不到檔案: {input_path}")
        return False
    
    # 如果沒有指定輸出路徑，使用原檔案名加上 _mono_16bit
    if output_path is None:
        output_path = input_path.parent / f"{input_path.stem}_mono_16bit{input_path.suffix}"
    else:
        output_path = Path(output_path)
    
    try:
        # 讀取原始音訊檔案
        print(f"📖 讀取檔案: {input_path}")
        data, sample_rate = sf.read(str(input_path))
        
        # 取得聲道數
        channels = data.shape[1] if len(data.shape) > 1 else 1
        
        print(f"📊 原始格式:")
        print(f"   取樣率: {sample_rate} Hz")
        print(f"   聲道數: {channels}")
        print(f"   資料型態: {data.dtype}")
        
        # --- 步驟 1: 確保數據格式統一為 float32 ---
        if data.dtype != np.float32 and data.dtype != np.float64:
            # 如果是整數格式，soundfile 讀取時通常會自動正規化，
            # 但為了保險，我們確保它在浮點數運算模式下
            if np.issubdtype(data.dtype, np.integer):
                 # 這裡簡化處理，讓 numpy 自動轉型
                 data = data.astype(np.float32)
                 # 注意：soundfile.read 預設通常就回傳 float64，除非指定 dtype
                 # 如果原始讀入就是 int，需要正規化到 -1.0 ~ 1.0 (視 int 位元數而定)
                 # 但最簡單的方法是讓 sf.read 保持預設，它會回傳正規化後的 float64

        # --- 步驟 2: 轉換為單聲道 (Mono) ---
        if channels > 1:
            print(f"\n🎧 偵測到 {channels} 聲道，正在混合為單聲道...")
            # 將所有聲道相加並取平均值
            # axis=1 表示沿著聲道方向操作
            data = np.mean(data, axis=1)
        else:
            print("\n🎧 原始檔案已為單聲道")

        # --- 步驟 3: 轉換取樣率 (如果需要) ---
        if target_sample_rate is not None and target_sample_rate != sample_rate:
            print(f"🔄 轉換取樣率: {sample_rate} Hz -> {target_sample_rate} Hz...")
            try:
                from scipy import signal
                # 計算新的樣本數
                num_samples = int(len(data) * target_sample_rate / sample_rate)
                # 重採樣 (因為已經轉成單聲道了，這裡是一維陣列)
                data = signal.resample(data, num_samples)
                sample_rate = target_sample_rate
                print(f"✅ 取樣率轉換完成")
            except ImportError:
                print("⚠️  需要 scipy 來轉換取樣率，請執行: pip install scipy")
                print("   將保持原始取樣率")

        # --- 步驟 4: 輸出為 16-bit PCM ---
        print(f"💾 寫入檔案 (PCM_16 Mono)...")
        
        sf.write(
            str(output_path),
            data,
            int(sample_rate),
            subtype='PCM_16', # 強制 16-bit
            format='WAV'
        )
        
        # 驗證輸出
        verify_data, verify_rate = sf.read(str(output_path))
        verify_channels = verify_data.shape[1] if len(verify_data.shape) > 1 else 1
        
        print(f"\n✅ 轉換成功!")
        print(f"📁 輸出路徑: {output_path}")
        print(f"📊 最終格式: {verify_rate}Hz, {verify_channels}聲道 (Mono), {np.dtype('int16') if verify_data.dtype == np.float64 else '16-bit PCM'}")
        
        return True
        
    except Exception as e:
        print(f"❌ 轉換失敗: {e}")
        import traceback
        traceback.print_exc()
        return False


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("用法: python convert_to_mono.py <input.wav> [output.wav] [sample_rate]")
        print("\n範例:")
        print("  python convert_to_mono.py sample.wav")
        print("  python convert_to_mono.py sample.wav output_mono.wav")
        print("  python convert_to_mono.py sample.wav output_44k_mono.wav 44100")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None
    target_rate = int(sys.argv[3]) if len(sys.argv) > 3 else None
    
    success = convert_wav_to_mono_16bit(input_file, output_file, target_rate)
    sys.exit(0 if success else 1)