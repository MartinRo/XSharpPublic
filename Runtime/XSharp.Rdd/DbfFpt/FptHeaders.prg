//
// Copyright (c) XSharp B.V.  All Rights Reserved.  
// Licensed under the Apache License, Version 2.0.  
// See License.txt in the project root for license information.
//

USING System.Text
USING XSharp.RDD.Enums
USING XSharp.RDD.Support
USING XSharp.RDD.CDX
USING System.Runtime.InteropServices
USING System.IO
BEGIN NAMESPACE XSharp.RDD
INTERNAL CLASS FptHeader
    // FoxPro memo Header:
    // Byte offset  Description
    // 00 - 03      Location of next free block
    // 04 - 05      Unused
    // 06 - 07      Block size (bytes per block)
    // 08 - 511     Unused
    // Note numbers are in FOX notation: Integers stored with the most significant byte first.

    PRIVATE Buffer AS BYTE[]
    INTERNAL CONST OFFSET_NEXTFREE  := 0 AS LONG
    INTERNAL CONST OFFSET_UNUSED    := 4 AS LONG
    INTERNAL CONST OFFSET_BLOCKSIZE := 6 AS LONG
    INTERNAL CONST FOXHEADER_LENGTH := 512 AS LONG
    INTERNAL CONST FOXHEADER_OFFSET := 0 AS LONG
    
    INTERNAL PROPERTY Size AS DWORD GET FOXHEADER_LENGTH

    INTERNAL CONSTRUCTOR()
        SELF:Buffer := BYTE[]{FOXHEADER_LENGTH}

    INTERNAL PROPERTY BlockSize AS WORD
        GET
            RETURN FoxToWord(Buffer, OFFSET_BLOCKSIZE)
        END GET
        SET
            IF value >= FPTMemo.MIN_FOXPRO_BLOCKSIZE
                WordToFox(value, Buffer, OFFSET_BLOCKSIZE)
            ELSE
                WordToFox(0, Buffer, OFFSET_BLOCKSIZE)
            ENDIF
        END SET
    END PROPERTY
    INTERNAL PROPERTY NextFree AS DWORD
        GET
            RETURN FoxToDword(Buffer, OFFSET_NEXTFREE)
        END GET
        SET
            DWordToFox(value, Buffer, OFFSET_NEXTFREE)
        END SET
    END PROPERTY
    INTERNAL PROPERTY UnUsed AS WORD
        GET
            RETURN FoxToWord(Buffer, OFFSET_UNUSED)
        END GET
        SET
            WordToFox(value, Buffer, OFFSET_UNUSED)
        END SET
    END PROPERTY

    INTERNAL METHOD Read(hFile AS IntPtr) AS LOGIC
        FSeek3(hFile, FOXHEADER_OFFSET, FS_SET)
        RETURN FRead3(hFile, Buffer, FOXHEADER_LENGTH) == FOXHEADER_LENGTH

    INTERNAL METHOD Write(hFile AS IntPtr) AS LOGIC
        FSeek3(hFile, FOXHEADER_OFFSET, FS_SET)
        RETURN FWrite3(hFile, Buffer, FOXHEADER_LENGTH) == FOXHEADER_LENGTH


END CLASS


INTERNAL CLASS FlexHeader
    // FlexFile Header starts as 512. Following positions are relative from pos 512
    // 00 - 08      Header "FlexFile3"
    // 09 - 09      Version Major
    // 10 - 10      Version Minor
    // 11 - 11      Index = defect
    // 12 - 15      Index Length
    // 16 - 19      Index location
    // 20 - 23      Update Count
    // 24 - 27      Root Pointer
    // 28 - 29      Alternative Block Size (allows block sizes < 32)

    PRIVATE Buffer AS BYTE[]
    INTERNAL CONST FLEXHEADER_OFFSET := 512 AS LONG
    INTERNAL CONST FLEXHEADER_LENGTH := 512 AS LONG
    INTERNAL CONST OFFSET_SIGNATURE :=  0 AS LONG
    INTERNAL CONST LEN_SIGNATURE    :=  9 AS LONG
    INTERNAL CONST OFFSET_MAJOR     :=  9 AS LONG
    INTERNAL CONST OFFSET_MINOR     := 10 AS LONG
    INTERNAL CONST OFFSET_DEFECT    := 11 AS LONG
    INTERNAL CONST OFFSET_INDEXLEN  := 12 AS LONG
    INTERNAL CONST OFFSET_INDEXLOC  := 16 AS LONG
    INTERNAL CONST OFFSET_UPDATE    := 20 AS LONG
    INTERNAL CONST OFFSET_ROOT      := 24 AS LONG
    INTERNAL CONST OFFSET_BLOCKSIZE := 28 AS LONG
    
    INTERNAL CONSTRUCTOR()
        SELF:Buffer := BYTE[]{FLEXHEADER_LENGTH}

    METHOD Create() AS VOID
        SELF:Signature := "FlexFile3"
        SELF:MajorVersion := 2
        SELF:MinorVersion := 8
        SELF:IndexDefect  := FALSE

    INTERNAL PROPERTY Size AS DWORD GET FLEXHEADER_LENGTH

    INTERNAL PROPERTY AltBlockSize  AS WORD  GET BuffToWord(SELF:Buffer, OFFSET_BLOCKSIZE)  SET WordToBuff(value, SELF:Buffer, OFFSET_BLOCKSIZE)
    INTERNAL PROPERTY MajorVersion  AS BYTE  GET SELF:Buffer[OFFSET_MAJOR]                  SET SELF:Buffer[OFFSET_MAJOR] := value
    INTERNAL PROPERTY MinorVersion  AS BYTE  GET SELF:Buffer[OFFSET_MINOR]                  SET SELF:Buffer[OFFSET_MINOR] := value
    INTERNAL PROPERTY IndexDefect   AS LOGIC GET SELF:Buffer[OFFSET_DEFECT] == 0            SET SELF:Buffer[OFFSET_DEFECT] := (BYTE) IIF(value,1,0)
    INTERNAL PROPERTY IndexLength   AS LONG  GET BuffToLong(SELF:Buffer, OFFSET_INDEXLEN )  SET LongToBuff(value, SELF:Buffer, OFFSET_INDEXLEN )
    INTERNAL PROPERTY IndexLocation AS LONG  GET BuffToLong(SELF:Buffer, OFFSET_INDEXLOC )  SET LongToBuff(value, SELF:Buffer, OFFSET_INDEXLOC )
    INTERNAL PROPERTY Root          AS LONG  GET BuffToLong(SELF:Buffer, OFFSET_ROOT )      SET LongToBuff(value, SELF:Buffer, OFFSET_ROOT )
    INTERNAL PROPERTY UpdateCount   AS LONG  GET BuffToLong(SELF:Buffer, OFFSET_UPDATE )    SET LongToBuff(value, SELF:Buffer, OFFSET_UPDATE )
    INTERNAL PROPERTY Signature     AS STRING
        // We can use System.Text.Encoding.ASCII because the flexfile header has no special characters
        GET
            RETURN System.Text.Encoding.ASCII:GetString(SELF:Buffer,0, 9)
        END GET
        SET
            VAR bytes := System.Text.Encoding.ASCII:GetBytes(value)
            System.Array.Copy(bytes,0, Buffer, OFFSET_SIGNATURE, LEN_SIGNATURE)
        END SET
    END PROPERTY
    INTERNAL METHOD Read(hFile AS IntPtr) AS LOGIC
        FSeek3(hFile, FLEXHEADER_OFFSET, FS_SET)
        RETURN FRead3(hFile, Buffer, FLEXHEADER_LENGTH) == FLEXHEADER_LENGTH

    INTERNAL METHOD Write(hFile AS IntPtr) AS LOGIC
        FSeek3(hFile, FLEXHEADER_OFFSET, FS_SET)
        RETURN FWrite3(hFile, Buffer, FLEXHEADER_LENGTH) == FLEXHEADER_LENGTH

    INTERNAL PROPERTY Valid AS LOGIC
        GET
            RETURN SELF:Signature == "FlexFile3"
        END GET
    END PROPERTY
END CLASS

END NAMESPACE
