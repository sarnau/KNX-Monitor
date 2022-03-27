//
//  KNX_DPT.swift
//

import Foundation

enum KNXDPT {
    case
        DPT_1_xxx,
        DPT_1_001_Switch,
        DPT_1_005_Alarm,
        DPT_1_008_UpDown,
        DPT_1_011_State,
        DPT_1_017_Trigger,
        DPT_1_024_DayNight,
        DPT_3_007_Control_Dimming,
        DPT_5_001_Scaling,
        DPT_5_010_Value_1_Ucount,
        DPT_7_600_Absolute_Colour_Temperature,
        DPT_9_xxx, // DPT2ByteFloat
        DPT_9_001_Value_Temp,
        DPT_9_002_Value_Tempd,
        DPT_9_004_Value_Lux,
        DPT_9_005_Value_Ws,
        DPT_9_006_Value_Pres,
        DPT_9_007_Value_Humidity,
        DPT_9_030_Concentration_µgm3,
        DPT_10_001_TimeOfDay, // DPTTime
        DPT_11_001_Date, // DPTTime
        DPT_12_100_LongTimePeriod_Sec,
        DPT_13_xxx, // DPT4ByteSigned
        DPT_13_013_ActiveEnergy_kWh,
        DPT_14_xxx, // DPT4ByteFloat
        DPT_14_019_Value_Electric_Current,
        DPT_14_027_Value_Electric_Potential,
        DPT_14_033_Value_Frequency,
        DPT_14_056_Value_Power,
        DPT_14_057_Value_Power_Factor,
        DPT_14_076_Value_Volume,
        DPT_undefined
}

private func from2ByteFloat(data: Data) -> Float {
    let data = from2ByteUInt(data: data)
    let exponent = (data >> 11) & 0x0F
    var significand = data & 0x7FF
    let sign = data >> 15
    if sign == 1 {
        significand -= 2048
    }
    return Float(significand << exponent) / 100
}

private func from3ByteTime(data: Data) -> Dictionary<String, Int> {
    return ["weekday": Int((data[0] & 0xE0) >> 5),
            "hours": Int(data[0] & 0x1F),
            "minutes": Int(data[1] & 0x3F),
            "seconds": Int(data[2] & 0x3F),
    ]
}

private func from3ByteDate(data: Data) -> Dictionary<String, Int> {
    let day: Int = Int(data[0] & 0x1F)
    let month: Int = Int(data[1] & 0x0F)
    var year: Int = Int(data[2] & 0x7F)
    if year >= 90 {
        year += 1900
    } else {
        year += 2000
    }
    return ["day": day,
            "month": month,
            "year": year,
    ]
}

private func from2ByteUInt(data: Data) -> UInt16 {
    return UInt16(bigEndian: data.withUnsafeBytes { $0.load(as: UInt16.self) })
}

private func from4ByteUInt(data: Data) -> UInt32 {
    return UInt32(bigEndian: data.withUnsafeBytes { $0.load(as: UInt32.self) })
}

private func from4ByteInt(data: Data) -> Int32 {
    return Int32(bigEndian: data.withUnsafeBytes { $0.load(as: Int32.self) })
}

private func from4ByteFloat(data: Data) -> Float {
    return Float(bitPattern: UInt32(bigEndian: data.withUnsafeBytes { $0.load(as: UInt32.self) }))
}

func convert_from_knx(data: Data, dpt: KNXDPT) -> String {
    switch dpt {
    case .DPT_1_xxx:
        return String(format: "1.xxx:%d", data[0])
    case .DPT_1_001_Switch:
        return "DPT_Switch(" + (data[0] != 0 ? "On" : "Off") + ")"
    case .DPT_1_005_Alarm:
        return "DPT_Alarm(" + (data[0] != 0 ? "Alarm" : "No alarm") + ")"
    case .DPT_1_008_UpDown:
        return "DPT_UpDown(" + (data[0] != 0 ? "Down" : "Up") + ")"
    case .DPT_1_011_State:
        return "DPT_State(" + (data[0] != 0 ? "Active" : "Inactive") + ")"
    case .DPT_1_017_Trigger:
        return "DPT_Trigger(" + (data[0] != 0 ? "trigger (1)" : "trigger (0)") + ")"
    case .DPT_1_024_DayNight:
        return "DPT_DayNight(" + (data[0] != 0 ? "Night" : "Day") + ")"
    case .DPT_3_007_Control_Dimming:
        return String(format: "DPT_Control_Dimming(%s,%d)", (data[0] & 1) != 0 ? "Increase" : "Decrease", (data[0] >> 1) & 7)
    case .DPT_5_001_Scaling: // percentage (0..100%)
        return String(format: "DPT_Scaling(%d%%)", Float(data[0]) * 0.3921566)
    case .DPT_5_010_Value_1_Ucount: // counter pulses (0..255)
        return String(format: "DPT_Value_1_Ucount(%d)", data[0])
    case .DPT_7_600_Absolute_Colour_Temperature:
        return String(format: "%dK", from2ByteUInt(data: data))
    case .DPT_9_xxx:
        return String(format: "9.xxx:%.1f", from2ByteFloat(data: data))
    case .DPT_9_001_Value_Temp:
        return String(format: "%.1f℃", from2ByteFloat(data: data))
    case .DPT_9_002_Value_Tempd:
        return String(format: "%.1fK", from2ByteFloat(data: data))
    case .DPT_9_004_Value_Lux:
        return String(format: "%.1flux", from2ByteFloat(data: data))
    case .DPT_9_005_Value_Ws:
        return String(format: "%.1fm/s", from2ByteFloat(data: data))
    case .DPT_9_006_Value_Pres:
        return String(format: "%.1fPa", from2ByteFloat(data: data))
    case .DPT_9_007_Value_Humidity:
        return String(format: "%.1f%%%", from2ByteFloat(data: data))
    case .DPT_9_030_Concentration_µgm3:
        return String(format: "%.1fµg/m³", from2ByteFloat(data: data))
    case .DPT_10_001_TimeOfDay:
        return "DPT_TimeOfDay" + from3ByteTime(data: data).description
    case .DPT_11_001_Date:
        return "DPT_Date" + from3ByteDate(data: data).description
    case .DPT_12_100_LongTimePeriod_Sec:
        return String(format: "%ds", from4ByteUInt(data: data))
    case .DPT_13_xxx:
        return String(format: "%d", from4ByteInt(data: data))
    case .DPT_13_013_ActiveEnergy_kWh:
        return String(format: "%dkWh", from4ByteInt(data: data))
    case .DPT_14_xxx:
        return String(format: "14.xxx:%.1f", from4ByteFloat(data: data))
    case .DPT_14_019_Value_Electric_Current:
        return String(format: "%.1fA", from4ByteFloat(data: data))
    case .DPT_14_027_Value_Electric_Potential:
        return String(format: "%.1fV", from4ByteFloat(data: data))
    case .DPT_14_033_Value_Frequency:
        return String(format: "%.1fHz", from4ByteFloat(data: data))
    case .DPT_14_056_Value_Power:
        return String(format: "%.1fW", from4ByteFloat(data: data))
    case .DPT_14_057_Value_Power_Factor:
        return String(format: "%.1fcos Φ", from4ByteFloat(data: data))
    case .DPT_14_076_Value_Volume:
        return String(format: "%.1fm³", from4ByteFloat(data: data))
    case .DPT_undefined:
        return "undefined:" + "0x" + data.hexEncodedString()
    }
}
