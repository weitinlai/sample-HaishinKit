#!/usr/bin/env python3
"""
將 WAV 檔案轉換為 16-bit PCM 格式
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


def convert_wav_to_16bit(input_path, output_path=None, target_sample_rate=None):
    """
    將 WAV 檔案轉換為 16-bit PCM 格式，可選轉換取樣率
    
    Args:
        input_path: 輸入 WAV 檔案路徑
        output_path: 輸出 WAV 檔案路徑（如果為 None，則覆蓋原檔案）
        target_sample_rate: 目標取樣率（如果為 None，則保持原始取樣率）
    """
    input_path = Path(input_path)
    
    if not input_path.exists():
        print(f"❌ 找不到檔案: {input_path}")
        return False
    
    # 如果沒有指定輸出路徑，使用原檔案名加上 _16bit
    if output_path is None:
        output_path = input_path.parent / f"{input_path.stem}_16bit{input_path.suffix}"
    else:
        output_path = Path(output_path)
    
    try:
        # 讀取原始音訊檔案
        print(f"📖 讀取檔案: {input_path}")
        data, sample_rate = sf.read(str(input_path))
        
        print(f"📊 原始格式:")
        print(f"   取樣率: {sample_rate} Hz")
        print(f"   聲道數: {data.shape[1] if len(data.shape) > 1 else 1}")
        print(f"   資料型態: {data.dtype}")
        print(f"   長度: {len(data)} 幀 ({len(data)/sample_rate:.2f} 秒)")
        
        # 確保數據在 -1.0 到 1.0 範圍內（如果是浮點數）
        if data.dtype == np.float32 or data.dtype == np.float64:
            # 如果已經是浮點數，確保在有效範圍內
            data = np.clip(data, -1.0, 1.0)
        else:
            # 如果是整數，先轉換為浮點數
            if data.dtype == np.int32:
                data = data.astype(np.float32) / 2147483648.0
            elif data.dtype == np.int24:
                # 24-bit 需要特殊處理
                data = data.astype(np.float32) / 8388608.0
            elif data.dtype == np.int16:
                data = data.astype(np.float32) / 32768.0
        
        # 如果需要轉換取樣率
        if target_sample_rate is not None and target_sample_rate != sample_rate:
            print(f"\n🔄 轉換取樣率: {sample_rate} Hz -> {target_sample_rate} Hz...")
            try:
                from scipy import signal
                # 計算重採樣比例
                num_samples = int(len(data) * target_sample_rate / sample_rate)
                # 重採樣
                if len(data.shape) > 1:
                    # 多聲道
                    resampled_data = np.zeros((num_samples, data.shape[1]), dtype=np.float32)
                    for ch in range(data.shape[1]):
                        resampled_data[:, ch] = signal.resample(data[:, ch].astype(np.float32), num_samples)
                else:
                    # 單聲道
                    resampled_data = signal.resample(data.astype(np.float32), num_samples)
                data = resampled_data
                sample_rate = target_sample_rate
                print(f"✅ 取樣率轉換完成")
            except ImportError:
                print("⚠️  需要 scipy 來轉換取樣率，使用 pip install scipy 安裝")
                print("   將保持原始取樣率")
        
        # 轉換為 16-bit PCM
        # soundfile 會自動處理轉換
        print(f"\n🔄 轉換為 16-bit PCM...")
        
        # 使用 soundfile 寫入，指定 subtype='PCM_16' 確保是 16-bit
        sf.write(
            str(output_path),
            data,
            int(sample_rate),
            subtype='PCM_16',
            format='WAV'
        )
        
        # 驗證輸出檔案
        verify_data, verify_rate = sf.read(str(output_path))
        print(f"\n✅ 轉換完成!")
        print(f"📁 輸出檔案: {output_path}")
        print(f"📊 輸出格式:")
        print(f"   取樣率: {verify_rate} Hz")
        print(f"   聲道數: {verify_data.shape[1] if len(verify_data.shape) > 1 else 1}")
        print(f"   資料型態: {verify_data.dtype}")
        print(f"   長度: {len(verify_data)} 幀 ({len(verify_data)/verify_rate:.2f} 秒)")
        
        return True
        
    except Exception as e:
        print(f"❌ 轉換失敗: {e}")
        import traceback
        traceback.print_exc()
        return False


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("用法: python convert_wav_to_16bit.py <input.wav> [output.wav] [sample_rate]")
        print("\n範例:")
        print("  python convert_wav_to_16bit.py sample.wav")
        print("  python convert_wav_to_16bit.py sample.wav sample_16bit.wav")
        print("  python convert_wav_to_16bit.py sample.wav sample_44k.wav 44100")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None
    target_rate = int(sys.argv[3]) if len(sys.argv) > 3 else None
    
    success = convert_wav_to_16bit(input_file, output_file, target_rate)
    sys.exit(0 if success else 1)

