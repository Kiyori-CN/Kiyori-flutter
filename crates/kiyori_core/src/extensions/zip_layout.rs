//! zip按名称合并目录项，故独立核对其公开偏移构成完整连续布局，不能遗漏隐藏同名条目。
//! 此处仅校验PKWARE头部/descriptor元数据；解压、CRC与ZIP64目录解析仍归zip库。
use super::{CoreError, error};
use std::{
    fs::File,
    io::{Read, Seek, SeekFrom},
};
use zip::read::ZipFile;

pub(super) struct Entry {
    header: u64,
    data: u64,
    central: u64,
    name: Vec<u8>,
    compressed: u64,
    size: u64,
    crc: u32,
}
impl Entry {
    pub(super) fn from_file<R: Read>(file: &ZipFile<'_, R>) -> Result<Self, CoreError> {
        Ok(Self {
            header: file.header_start(),
            data: file.data_start().ok_or_else(invalid)?,
            central: file.central_header_start(),
            name: file.name_raw().to_vec(),
            compressed: file.compressed_size(),
            size: file.size(),
            crc: file.crc32(),
        })
    }
}
fn invalid() -> CoreError {
    error("扩展ZIP局部头、目录、descriptor或完整布局不一致")
}
fn u16_at(bytes: &[u8], offset: usize) -> u16 {
    u16::from_le_bytes(bytes[offset..offset + 2].try_into().unwrap())
}
fn u32_at(bytes: &[u8], offset: usize) -> u32 {
    u32::from_le_bytes(bytes[offset..offset + 4].try_into().unwrap())
}
fn u64_at(bytes: &[u8], offset: usize) -> u64 {
    u64::from_le_bytes(bytes[offset..offset + 8].try_into().unwrap())
}
fn read(file: &mut File, offset: u64, count: usize) -> Result<Vec<u8>, CoreError> {
    let mut bytes = vec![0; count];
    file.seek(SeekFrom::Start(offset))
        .and_then(|_| file.read_exact(&mut bytes))
        .map_err(|_| invalid())?;
    Ok(bytes)
}
fn sizes(local: &[u8], extra: &[u8]) -> Result<(u64, u64), CoreError> {
    let mut size = u32_at(local, 22) as u64;
    let mut compressed = u32_at(local, 18) as u64;
    if size != u32::MAX as u64 && compressed != u32::MAX as u64 {
        return Ok((size, compressed));
    }
    let mut remaining = extra;
    while remaining.len() >= 4 {
        let id = u16_at(remaining, 0);
        let length = u16_at(remaining, 2) as usize;
        let payload = remaining.get(4..4 + length).ok_or_else(invalid)?;
        if id == 1 {
            let mut offset = 0;
            if size == u32::MAX as u64 {
                if payload.len() < offset + 8 {
                    return Err(invalid());
                }
                size = u64_at(payload, offset);
                offset += 8;
            }
            if compressed == u32::MAX as u64 {
                if payload.len() < offset + 8 {
                    return Err(invalid());
                }
                compressed = u64_at(payload, offset);
            }
            return Ok((size, compressed));
        }
        remaining = &remaining[4 + length..];
    }
    Err(invalid())
}
fn descriptor(bytes: &[u8], entry: &Entry) -> bool {
    let values = if matches!(bytes.len(), 16 | 24) && u32_at(bytes, 0) == 0x08074b50 {
        &bytes[4..]
    } else {
        bytes
    };
    match values.len() {
        12 => {
            u32_at(values, 0) == entry.crc
                && u32_at(values, 4) as u64 == entry.compressed
                && u32_at(values, 8) as u64 == entry.size
        }
        20 => {
            u32_at(values, 0) == entry.crc
                && u64_at(values, 4) == entry.compressed
                && u64_at(values, 12) == entry.size
        }
        _ => false,
    }
}
pub(super) fn check(
    file: &mut File,
    directory: u64,
    entries: &mut [Entry],
) -> Result<(), CoreError> {
    entries.sort_by_key(|entry| entry.central);
    let mut position = directory;
    for entry in entries.iter() {
        if position != entry.central {
            return Err(invalid());
        }
        let central = read(file, position, 46)?;
        if u32_at(&central, 0) != 0x02014b50 || u16_at(&central, 28) as usize != entry.name.len() {
            return Err(invalid());
        }
        if read(file, position + 46, entry.name.len())? != entry.name {
            return Err(invalid());
        }
        position += 46
            + u16_at(&central, 28) as u64
            + u16_at(&central, 30) as u64
            + u16_at(&central, 32) as u64;
    }
    let end = read(file, position, 4)?;
    if !matches!(u32_at(&end, 0), 0x06054b50 | 0x06064b50) {
        return Err(invalid());
    }
    entries.sort_by_key(|entry| entry.header);
    position = 0;
    for (index, entry) in entries.iter().enumerate() {
        if position != entry.header {
            return Err(invalid());
        }
        let local = read(file, position, 30)?;
        let central = read(file, entry.central, 46)?;
        if u32_at(&local, 0) != 0x04034b50
            || local[4..14] != central[6..16]
            || u16_at(&local, 26) as usize != entry.name.len()
        {
            return Err(invalid());
        }
        let extra_len = u16_at(&local, 28) as usize;
        let data = position + 30 + entry.name.len() as u64 + extra_len as u64;
        if data != entry.data || read(file, position + 30, entry.name.len())? != entry.name {
            return Err(invalid());
        }
        let extra = read(file, position + 30 + entry.name.len() as u64, extra_len)?;
        let (size, compressed) = sizes(&local, &extra)?;
        let using_descriptor = u16_at(&local, 6) & 8 != 0;
        let crc = u32_at(&local, 14);
        if (if using_descriptor {
            crc != 0 && crc != entry.crc
        } else {
            crc != entry.crc
        }) || (if using_descriptor {
            (size != 0 && size != entry.size) || (compressed != 0 && compressed != entry.compressed)
        } else {
            size != entry.size || compressed != entry.compressed
        }) {
            return Err(invalid());
        }
        let data_end = data.checked_add(entry.compressed).ok_or_else(invalid)?;
        let next = entries.get(index + 1).map_or(directory, |next| next.header);
        let gap = next.checked_sub(data_end).ok_or_else(invalid)?;
        if using_descriptor {
            if !matches!(gap, 12 | 16 | 20 | 24)
                || !descriptor(&read(file, data_end, gap as usize)?, entry)
            {
                return Err(invalid());
            }
        } else if gap != 0 {
            return Err(invalid());
        }
        position = next;
    }
    if position != directory {
        return Err(invalid());
    }
    Ok(())
}
