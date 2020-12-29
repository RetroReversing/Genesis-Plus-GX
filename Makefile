DEBUG = 0
LOGSOUND = 0
FRONTEND_SUPPORTS_RGB565 = 1
HAVE_CHD = 1
HAVE_SYS_PARAM = 1
HAVE_CDROM = 0
USE_PER_SOUND_CHANNELS_CONFIG = 1

CORE_DIR := .

SPACE :=
SPACE := $(SPACE) $(SPACE)
BACKSLASH :=
BACKSLASH := \$(BACKSLASH)
filter_out1 = $(filter-out $(firstword $1),$1)
filter_out2 = $(call filter_out1,$(call filter_out1,$1))
unixpath = $(subst \,/,$1)
unixcygpath = /$(subst :,,$(call unixpath,$1))

# system platform
ifeq ($(platform),)
   platform = unix
   ifeq ($(shell uname -s),)
      platform = win
      EXE_EXT = .exe
   else ifneq ($(findstring MINGW,$(shell uname -s)),)
      platform = win
   else ifneq ($(findstring Darwin,$(shell uname -s)),)
      platform = osx
      arch = intel
      ifeq ($(shell uname -p),powerpc)
         arch = ppc
      endif
   else ifneq ($(findstring win,$(shell uname -s)),)
      platform = win
   endif
else ifneq (,$(findstring armv,$(platform)))
	ifeq (,$(findstring classic_,$(platform)))
    override platform += unix
  endif
else ifneq (,$(findstring rpi,$(platform)))
   override platform += unix
endif

# system platform
system_platform = unix
ifeq ($(shell uname -a),)
	EXE_EXT = .exe
	system_platform = win
else ifneq ($(findstring Darwin,$(shell uname -a)),)
	system_platform = osx
	arch = intel
	ifeq ($(shell uname -p),powerpc)
		arch = ppc
	endif
else ifneq ($(findstring MINGW,$(shell uname -a)),)
	system_platform = win
endif

TARGET_NAME := genesis_plus_gx

LIBS := -lm

ifneq ($(SANITIZER),)
   CFLAGS   := -fsanitize=$(SANITIZER) $(CFLAGS)
   CXXFLAGS := -fsanitize=$(SANITIZER) $(CXXFLAGS)
   LDFLAGS  := -fsanitize=$(SANITIZER) $(LDFLAGS)
endif

GIT_VERSION ?= " $(shell git rev-parse --short HEAD || echo unknown)"
ifneq ($(GIT_VERSION)," unknown")
   CFLAGS += -DGIT_VERSION=\"$(GIT_VERSION)\"
endif

# Unix
ifneq (,$(findstring unix,$(platform)))
   TARGET := $(TARGET_NAME)_libretro.so
   fpic := -fPIC
   SHARED := -shared -Wl,--version-script=$(CORE_DIR)/libretro/link.T -Wl,--no-undefined
   ENDIANNESS_DEFINES := -DLSB_FIRST -DBYTE_ORDER=LITTLE_ENDIAN
   PLATFORM_DEFINES := -DHAVE_ZLIB

   ifneq ($(findstring Linux,$(shell uname -s)),)
     HAVE_CDROM = 1
   endif

   # Raspberry Pi
   ifneq (,$(findstring rpi,$(platform)))
      ENDIANNESS_DEFINES += -DALIGN_LONG
      CFLAGS += -fomit-frame-pointer -ffast-math
      ifneq (,$(findstring rpi1,$(platform)))
         PLATFORM_DEFINES += -DARM11 -marm -march=armv6j -mfpu=vfp -mfloat-abi=hard
      else ifneq (,$(findstring rpi2,$(platform)))
         PLATFORM_DEFINES += -DARM -marm -mcpu=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard
      else ifneq (,$(findstring rpi3,$(platform)))
         PLATFORM_DEFINES += -DARM -marm -mcpu=cortex-a53 -mfpu=neon-fp-armv8 -mfloat-abi=hard
      else ifneq (,$(findstring rpi4_64,$(platform)))
         PLATFORM_DEFINES += -DARM -march=armv8-a+crc+simd -mtune=cortex-a72
      endif
   endif
   
# (armv8 a35, hard point, neon based) ###
# Playstation Classic
else ifeq ($(platform), classic_armv8_a35)
	TARGET := $(TARGET_NAME)_libretro.so
	fpic := -fPIC
  SHARED := -shared -Wl,--version-script=$(CORE_DIR)/libretro/link.T -Wl,--no-undefined
	CFLAGS += -Ofast \
	-flto=4 -fwhole-program -fuse-linker-plugin \
	-fdata-sections -ffunction-sections -Wl,--gc-sections \
	-fno-stack-protector -fno-ident -fomit-frame-pointer \
	-falign-functions=1 -falign-jumps=1 -falign-loops=1 \
	-fno-unwind-tables -fno-asynchronous-unwind-tables -fno-unroll-loops \
	-fmerge-all-constants -fno-math-errno \
	-marm -mtune=cortex-a35 -mfpu=neon-fp-armv8 -mfloat-abi=hard
	CXXFLAGS += $(CFLAGS)
	ASFLAGS += $(CFLAGS)
	HAVE_NEON = 1
	ARCH = arm
	BUILTIN_GPU = neon
	USE_DYNAREC = 1
	ENDIANNESS_DEFINES := -DLSB_FIRST -DBYTE_ORDER=LITTLE_ENDIAN -DALIGN_LONG
	PLATFORM_DEFINES := -DHAVE_ZLIB
	CFLAGS += -march=armv8-a
	LDFLAGS += -static-libgcc -static-libstdc++
#######################################

# Portable Linux
else ifeq ($(platform), linux-portable)
   TARGET := $(TARGET_NAME)_libretro.so
   fpic := -fPIC -nostdlib
   SHARED := -shared -Wl,--version-script=$(CORE_DIR)/libretro/link.T
   ENDIANNESS_DEFINES := -DLSB_FIRST -DBYTE_ORDER=LITTLE_ENDIAN
   PLATFORM_DEFINES := -DHAVE_ZLIB
   LIBS =

# OS X
else ifeq ($(platform), osx)
   TARGET := $(TARGET_NAME)_libretro.dylib
   fpic := -fPIC
   SHARED := -dynamiclib
ifeq ($(arch),ppc)
		ENDIANNESS_DEFINES := -DBYTE_ORDER=BIG_ENDIAN -DCPU_IS_BIG_ENDIAN=1 -DWORDS_BIGENDIAN=1 -DHAVE_NO_LANGEXTRA
   else
      ENDIANNESS_DEFINES := -DLSB_FIRST -DBYTE_ORDER=LITTLE_ENDIAN
   endif
   PLATFORM_DEFINES := -DHAVE_ZLIB

   OSXVER = `sw_vers -productVersion | cut -d. -f 2`
   OSX_LT_MAVERICKS = `(( $(OSXVER) <= 9)) && echo "YES"`
   fpic += -mmacosx-version-min=10.15
   ifndef ($(NOUNIVERSAL))
      CFLAGS  += $(ARCHFLAGS)
      LDFLAGS += $(ARCHFLAGS)
   endif

# iOS
else ifneq (,$(findstring ios,$(platform)))
   TARGET := $(TARGET_NAME)_libretro_ios.dylib
   fpic := -fPIC
   SHARED := -dynamiclib
   ENDIANNESS_DEFINES := -DLSB_FIRST -DBYTE_ORDER=LITTLE_ENDIAN
   PLATFORM_DEFINES := -DHAVE_ZLIB

   ifeq ($(IOSSDK),)
      IOSSDK := $(shell xcrun -sdk iphoneos -show-sdk-path)
   endif

   ifeq ($(platform),ios-arm64)
      CC = cc -arch arm64 -isysroot $(IOSSDK)
      CXX = c++ -arch arm64 -isysroot $(IOSSDK)
   else
      CC = cc -arch armv7 -isysroot $(IOSSDK)
      CXX = c++ -arch arm64 -isysroot $(IOSSDK)
   endif
   ifeq ($(platform),$(filter $(platform),ios9 ios-arm64))
      CC += -miphoneos-version-min=8.0
      CXX += -miphoneos-version-min=8.0
      PLATFORM_DEFINES += -miphoneos-version-min=8.0
   else
      CC += -miphoneos-version-min=5.0
      CXX += -miphoneos-version-min=5.0
      PLATFORM_DEFINES += -miphoneos-version-min=5.0
   endif

# tvOS
else ifeq ($(platform), tvos-arm64)
   TARGET := $(TARGET_NAME)_libretro_tvos.dylib
   fpic := -fPIC
   SHARED := -dynamiclib
   ENDIANNESS_DEFINES := -DLSB_FIRST -DBYTE_ORDER=LITTLE_ENDIAN
   PLATFORM_DEFINES := -DHAVE_ZLIB

   ifeq ($(IOSSDK),)
      IOSSDK := $(shell xcrun -sdk appletvos -show-sdk-path)
   endif

# Theos
else ifeq ($(platform), theos_ios)
   DEPLOYMENT_IOSVERSION = 5.0
   TARGET = iphone:latest:$(DEPLOYMENT_IOSVERSION)
   ARCHS = armv7 armv7s
   TARGET_IPHONEOS_DEPLOYMENT_VERSION=$(DEPLOYMENT_IOSVERSION)
   THEOS_BUILD_DIR := objs
   include $(THEOS)/makefiles/common.mk

   LIBRARY_NAME = $(TARGET_NAME)_libretro_ios

   ENDIANNESS_DEFINES := -DLSB_FIRST -DBYTE_ORDER=LITTLE_ENDIAN
   PLATFORM_DEFINES := -DHAVE_ZLIB

# QNX
else ifeq ($(platform), qnx)
   TARGET := $(TARGET_NAME)_libretro_qnx.so
   fpic := -fPIC
   SHARED := -shared -Wl,--version-script=$(CORE_DIR)/libretro/link.T -Wl,--no-undefined
   ENDIANNESS_DEFINES := -DLSB_FIRST -DBYTE_ORDER=LITTLE_ENDIAN
   PLATFORM_DEFINES := -DHAVE_ZLIB
   CC = qcc -Vgcc_ntoarmv7le
   CXX = qcc -Vgcc_ntoarmv7le
   AR = qcc -Vgcc_ntoarmv7le
   PLATFORM_DEFINES := -D__BLACKBERRY_QNX__ -marm -mcpu=cortex-a9 -mfpu=neon -mfloat-abi=softfp

# PS3
else ifneq (,$(filter $(platform), psl1ght))
   TARGET := $(TARGET_NAME)_libretro_ps3.a
   PLATFORM_DEFINES := -D__PSLIGHT__ -DALT_RENDER
	ENDIANNESS_DEFINES := -DBYTE_ORDER=BIG_ENDIAN -DBYTE_ORDER=BIG_ENDIAN -DCPU_IS_BIG_ENDIAN=1 -DWORDS_BIGENDIAN=1
   STATIC_LINKING = 1
   HAVE_SYS_PARAM = 0

   # Lightweight PS3 Homebrew SDK
   ifneq (,$(findstring psl1ght,$(platform)))
      TARGET := $(TARGET_NAME)_libretro_$(platform).a
      CC = $(PS3DEV)/ppu/bin/ppu-gcc$(EXE_EXT)
      CXX = $(PS3DEV)/ppu/bin/ppu-g++$(EXE_EXT)
      AR = $(PS3DEV)/ppu/bin/ppu-ar$(EXE_EXT)
   endif

# PSP
else ifeq ($(platform), psp1)
   TARGET := $(TARGET_NAME)_libretro_$(platform).a
   CC = psp-gcc$(EXE_EXT)
   CXX = psp-g++$(EXE_EXT)
   AR = psp-ar$(EXE_EXT)
   ENDIANNESS_DEFINES := -DLSB_FIRST -DBYTE_ORDER=LITTLE_ENDIAN
   PLATFORM_DEFINES := -DPSP
   CFLAGS += -G0
   STATIC_LINKING = 1
   USE_PER_SOUND_CHANNELS_CONFIG = 0

# Vita
else ifeq ($(platform), vita)
   TARGET := $(TARGET_NAME)_libretro_$(platform).a
   CC = arm-vita-eabi-gcc$(EXE_EXT)
   CXX = arm-vita-eabi-g++$(EXE_EXT)
   AR = arm-vita-eabi-ar$(EXE_EXT)
   CFLAGS += -O3 -mfloat-abi=hard -ffast-math -fsingle-precision-constant
   ENDIANNESS_DEFINES := -DLSB_FIRST -DALIGN_LONG -DALT_RENDERER -DHAVE_ALLOCA_H -DBYTE_ORDER=LITTLE_ENDIAN
   PLATFORM_DEFINES := -DVITA
   STATIC_LINKING = 1
   USE_PER_SOUND_CHANNELS_CONFIG = 0

# CTR (3DS)
else ifeq ($(platform), ctr)
   TARGET := $(TARGET_NAME)_libretro_$(platform).a
   CC = $(DEVKITARM)/bin/arm-none-eabi-gcc$(EXE_EXT)
   CXX = $(DEVKITARM)/bin/arm-none-eabi-g++$(EXE_EXT)
   AR = $(DEVKITARM)/bin/arm-none-eabi-ar$(EXE_EXT)
   ENDIANNESS_DEFINES := -DLSB_FIRST -DALIGN_LONG -DBYTE_ORDER=LITTLE_ENDIAN -DUSE_DYNAMIC_ALLOC
   PLATFORM_DEFINES := -DARM11 -D_3DS
   CFLAGS += -march=armv6k -mtune=mpcore -mfloat-abi=hard -marm -mfpu=vfp
   CFLAGS += -Wall -mword-relocations
   CFLAGS += -fomit-frame-pointer -ffast-math
   STATIC_LINKING = 1
   USE_PER_SOUND_CHANNELS_CONFIG = 0

# Xbox 360
else ifeq ($(platform), xenon)
   TARGET := $(TARGET_NAME)_libretro_xenon360.a
   CC = xenon-gcc$(EXE_EXT)
   CXX = xenon-g++$(EXE_EXT)
   AR = xenon-ar$(EXE_EXT)
   PLATFORM_DEFINES := -D__LIBXENON__ -DALT_RENDER
	ENDIANNESS_DEFINES := -DBYTE_ORDER=BIG_ENDIAN -DBYTE_ORDER=BIG_ENDIAN -DCPU_IS_BIG_ENDIAN=1 -DWORDS_BIGENDIAN=1
   STATIC_LINKING = 1

# Nintendo GameCube / Wii / WiiU
else ifneq (,$(filter $(platform), ngc wii wiiu))
   TARGET := $(TARGET_NAME)_libretro_$(platform).a
   CC = $(DEVKITPPC)/bin/powerpc-eabi-gcc$(EXE_EXT)
   CXX = $(DEVKITPPC)/bin/powerpc-eabi-g++$(EXE_EXT)
   AR = $(DEVKITPPC)/bin/powerpc-eabi-ar$(EXE_EXT)
	ENDIANNESS_DEFINES := -DBYTE_ORDER=BIG_ENDIAN -DCPU_IS_BIG_ENDIAN=1 -DWORDS_BIGENDIAN=1
   PLATFORM_DEFINES := -DGEKKO -mcpu=750 -meabi -mhard-float -DALT_RENDER
   PLATFORM_DEFINES += -U__INT32_TYPE__ -U __UINT32_TYPE__ -D__INT32_TYPE__=int
   STATIC_LINKING = 1
   USE_PER_SOUND_CHANNELS_CONFIG = 0

   # Nintendo WiiU
   ifneq (,$(findstring wiiu,$(platform)))
      PLATFORM_DEFINES += -DWIIU -DHW_RVL -DUSE_DYNAMIC_ALLOC

   # Nintendo Wii
   else ifneq (,$(findstring wii,$(platform)))
      PLATFORM_DEFINES += -DHW_RVL -mrvl

   # Nintendo GameCube
   else ifneq (,$(findstring ngc,$(platform)))
      PLATFORM_DEFINES += -DHW_DOL -mrvl
   endif

# Nintendo Switch (libtransistor)
else ifeq ($(platform), switch)
   TARGET := $(TARGET_NAME)_libretro_$(platform).a
   include $(LIBTRANSISTOR_HOME)/libtransistor.mk
   CFLAGS += -fomit-frame-pointer -ffast-math
   STATIC_LINKING=1
   STATIC_LINKING_LINK=1

# Nintendo Switch (libnx)
else ifeq ($(platform), libnx)
   include $(DEVKITPRO)/libnx/switch_rules
   TARGET := $(TARGET_NAME)_libretro_$(platform).a
   CFLAGS += -D__SWITCH__ -DHAVE_LIBNX -I$(LIBNX)/include/ -fPIE -Wl,--allow-multiple-definition -specs=$(LIBNX)/switch.specs
   PLATFORM_DEFINES += -DARM -march=armv8-a -mtune=cortex-a57 -mtp=soft -DLSB_FIRST -DBYTE_ORDER=LITTLE_ENDIAN -D__LIBRETRO__ -DALIGN_LONG -DALIGN_WORD -DM68K_OVERCLOCK_SHIFT=20 -DHAVE_ZLIB
   STATIC_LINKING=1
   STATIC_LINKING_LINK=1

# emscripten
else ifeq ($(platform), emscripten)
   TARGET := $(TARGET_NAME)_libretro_$(platform).bc
   ENDIANNESS_DEFINES := -DLSB_FIRST -DALIGN_LONG -DBYTE_ORDER=LITTLE_ENDIAN -DHAVE_ZLIB
   STATIC_LINKING = 1

# GCW0
else ifeq ($(platform), gcw0)
   TARGET := $(TARGET_NAME)_libretro.so
   CC = /opt/gcw0-toolchain/usr/bin/mipsel-linux-gcc
   CXX = /opt/gcw0-toolchain/usr/bin/mipsel-linux-g++
   AR = /opt/gcw0-toolchain/usr/bin/mipsel-linux-ar
   SHARED := -shared -Wl,--version-script=$(CORE_DIR)/libretro/link.T -Wl,--no-undefined
   fpic := -fPIC
   LDFLAGS += $(PTHREAD_FLAGS)
   CFLAGS += $(PTHREAD_FLAGS) -G0
   CFLAGS += -ffast-math -march=mips32 -mtune=mips32r2 -mhard-float -fomit-frame-pointer
   ENDIANNESS_DEFINES := -DLSB_FIRST -DBYTE_ORDER=LITTLE_ENDIAN -DALIGN_LONG
   USE_PER_SOUND_CHANNELS_CONFIG = 0

# Windows MSVC 2003 Xbox 1
else ifeq ($(platform), xbox1_msvc2003)
TARGET := $(TARGET_NAME)_libretro_xdk1.lib
CC  = CL.exe
CXX  = CL.exe
LD   = lib.exe
HAVE_CDROM = 1

export INCLUDE := $(XDK)/xbox/include
export LIB := $(XDK)/xbox/lib
PATH := $(call unixcygpath,$(XDK)/xbox/bin/vc71):$(PATH)

ENDIANNESS_DEFINES := -DLSB_FIRST -DBYTE_ORDER=LITTLE_ENDIAN
PSS_STYLE :=2
CFLAGS   += -D_XBOX -D_XBOX1
CXXFLAGS += -D_XBOX -D_XBOX1
STATIC_LINKING=1
HAS_GCC := 0
HAVE_SYS_PARAM = 0
# Windows MSVC 2010 Xbox 360
else ifeq ($(platform), xbox360_msvc2010)
TARGET := $(TARGET_NAME)_libretro_xdk360.lib
MSVCBINDIRPREFIX = $(XEDK)/bin/win32
CC  = "$(MSVCBINDIRPREFIX)/cl.exe"
CXX  = "$(MSVCBINDIRPREFIX)/cl.exe"
LD   = "$(MSVCBINDIRPREFIX)/lib.exe"

export INCLUDE := $(XEDK)/include/xbox
export LIB := $(XEDK)/lib/xbox
PSS_STYLE :=2
CFLAGS   += -D_XBOX -D_XBOX360
CXXFLAGS += -D_XBOX -D_XBOX360
STATIC_LINKING=1
HAS_GCC := 0
HAVE_SYS_PARAM = 0
HAVE_CDROM = 1
# Windows MSVC 2010 x64
else ifeq ($(platform), windows_msvc2010_x64)
	CC  = cl.exe
	CXX = cl.exe

HAVE_SYS_PARAM = 0

PATH := $(shell IFS=$$'\n'; cygpath "$(VS100COMNTOOLS)../../VC/bin/amd64"):$(PATH)
PATH := $(PATH):$(shell IFS=$$'\n'; cygpath "$(VS100COMNTOOLS)../IDE")
LIB := $(shell IFS=$$'\n'; cygpath -w "$(VS100COMNTOOLS)../../VC/lib/amd64")
INCLUDE := $(shell IFS=$$'\n'; cygpath -w "$(VS100COMNTOOLS)../../VC/include")

WindowsSdkDir := $(shell reg query "HKLM\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v7.0A" -v "InstallationFolder" | grep -o '[A-Z]:\\.*')
WindowsSdkDir ?= $(shell reg query "HKLM\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v7.1A" -v "InstallationFolder" | grep -o '[A-Z]:\\.*')

WindowsSdkDirInc := $(WindowsSdkDir)Include
WindowsSdkDirInc ?= $(WindowsSdkDir)Include

INCFLAGS_PLATFORM = -I"$(WindowsSdkDirInc)"
export INCLUDE := $(INCLUDE)
export LIB := $(LIB);$(WindowsSdkDir)\Lib\x64
TARGET := $(TARGET_NAME)_libretro.dll
PSS_STYLE :=2
LDFLAGS += -DLL
LIBS =

# Windows MSVC 2017 all architectures
else ifneq (,$(findstring windows_msvc2017,$(platform)))
    
	PlatformSuffix = $(subst windows_msvc2017_,,$(platform))
	ifneq (,$(findstring desktop,$(PlatformSuffix)))
		WinPartition = desktop
		MSVC2017CompileFlags = -DWINAPI_FAMILY=WINAPI_FAMILY_DESKTOP_APP -FS
		LDFLAGS += -MANIFEST -LTCG:incremental -NXCOMPAT -DYNAMICBASE -DEBUG -OPT:REF -INCREMENTAL:NO -SUBSYSTEM:WINDOWS -MANIFESTUAC:"level='asInvoker' uiAccess='false'" -OPT:ICF -ERRORREPORT:PROMPT -NOLOGO -TLBID:1
		LIBS := kernel32.lib user32.lib gdi32.lib winspool.lib comdlg32.lib advapi32.lib
		HAVE_CDROM = 1
	else ifneq (,$(findstring uwp,$(PlatformSuffix)))
		WinPartition = uwp
		MSVC2017CompileFlags = -DWINAPI_FAMILY=WINAPI_FAMILY_APP -D_WINDLL -D_UNICODE -DUNICODE -D__WRL_NO_DEFAULT_LIB__ -FS
		MSVC2017CxxFlags = -EHsc -ZW
		LDFLAGS += -APPCONTAINER -NXCOMPAT -DYNAMICBASE -MANIFEST:NO -LTCG -OPT:REF -SUBSYSTEM:CONSOLE -OPT:ICF -ERRORREPORT:PROMPT -NOLOGO -TLBID:1 -DEBUG:FULL -WINMD:NO /nodefaultlib:vccorlib /nodefaultlib:msvcrt vccorlib.lib msvcrt.lib
		LIBS := WindowsApp.lib
	endif

	CFLAGS += $(MSVC2017CompileFlags)
	CXXFLAGS += $(MSVC2017CompileFlags) $(MSVC2017CxxFlags)

	TargetArchMoniker = $(subst $(WinPartition)_,,$(PlatformSuffix))

	CC  = cl.exe
	CXX = cl.exe
	LD = link.exe

    HAVE_SYS_PARAM = 0

	reg_query = $(call filter_out2,$(subst $2,,$(shell reg query "$2" -v "$1")))
	fix_path = $(subst $(SPACE),\ ,$(subst \,/,$1))

	ProgramFiles86w := $(shell cmd //c "echo %PROGRAMFILES(x86)%")
	ProgramFiles86 := $(shell cygpath "$(ProgramFiles86w)")

	WindowsSdkDir ?= $(call reg_query,InstallationFolder,HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Microsoft SDKs\Windows\v10.0)
	WindowsSdkDir ?= $(call reg_query,InstallationFolder,HKEY_CURRENT_USER\SOFTWARE\Wow6432Node\Microsoft\Microsoft SDKs\Windows\v10.0)
	WindowsSdkDir ?= $(call reg_query,InstallationFolder,HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v10.0)
	WindowsSdkDir ?= $(call reg_query,InstallationFolder,HKEY_CURRENT_USER\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v10.0)
	WindowsSdkDir := $(WindowsSdkDir)

	WindowsSDKVersion ?= $(firstword $(foreach folder,$(subst $(subst \,/,$(WindowsSdkDir)Include/),,$(wildcard $(call fix_path,$(WindowsSdkDir)Include\*))),$(if $(wildcard $(call fix_path,$(WindowsSdkDir)Include/$(folder)/um/Windows.h)),$(folder),)))
	WindowsSDKVersion := $(WindowsSDKVersion)

	VsInstallBuildTools = $(ProgramFiles86)/Microsoft Visual Studio/2017/BuildTools
	VsInstallEnterprise = $(ProgramFiles86)/Microsoft Visual Studio/2017/Enterprise
	VsInstallProfessional = $(ProgramFiles86)/Microsoft Visual Studio/2017/Professional
	VsInstallCommunity = $(ProgramFiles86)/Microsoft Visual Studio/2017/Community

	VsInstallRoot ?= $(shell if [ -d "$(VsInstallBuildTools)" ]; then echo "$(VsInstallBuildTools)"; fi)
	ifeq ($(VsInstallRoot), )
		VsInstallRoot = $(shell if [ -d "$(VsInstallEnterprise)" ]; then echo "$(VsInstallEnterprise)"; fi)
	endif
	ifeq ($(VsInstallRoot), )
		VsInstallRoot = $(shell if [ -d "$(VsInstallProfessional)" ]; then echo "$(VsInstallProfessional)"; fi)
	endif
	ifeq ($(VsInstallRoot), )
		VsInstallRoot = $(shell if [ -d "$(VsInstallCommunity)" ]; then echo "$(VsInstallCommunity)"; fi)
	endif
	VsInstallRoot := $(VsInstallRoot)

	VcCompilerToolsVer := $(shell cat "$(VsInstallRoot)/VC/Auxiliary/Build/Microsoft.VCToolsVersion.default.txt" | grep -o '[0-9\.]*')
	VcCompilerToolsDir := $(VsInstallRoot)/VC/Tools/MSVC/$(VcCompilerToolsVer)
	# platform.winmd seems to be platform independent but only lives in the x86 lib directory
	VcCompilerToolsStoreReferencesDir := $(shell IFS=$$'\n'; cygpath -w "$(VcCompilerToolsDir)/lib/x86/store/references")

	WindowsSDKSharedIncludeDir := $(shell cygpath -w "$(WindowsSdkDir)\Include\$(WindowsSDKVersion)\shared")
	WindowsSDKUCRTIncludeDir := $(shell cygpath -w "$(WindowsSdkDir)\Include\$(WindowsSDKVersion)\ucrt")
	WindowsSDKUMIncludeDir := $(shell cygpath -w "$(WindowsSdkDir)\Include\$(WindowsSDKVersion)\um")
	WindowsSDKWinRTIncludeDir := $(shell cygpath -w "$(WindowsSdkDir)\Include\$(WindowsSDKVersion)\winrt")
	WindowsSDKUCRTLibDir := $(shell cygpath -w "$(WindowsSdkDir)\Lib\$(WindowsSDKVersion)\ucrt\$(TargetArchMoniker)")
	WindowsSDKUMLibDir := $(shell cygpath -w "$(WindowsSdkDir)\Lib\$(WindowsSDKVersion)\um\$(TargetArchMoniker)")
	WindowsSDKUnionMetadataDir := $(shell cygpath -w "$(WindowsSdkDir)\UnionMetadata\$(WindowsSDKVersion)")

	# For some reason the HostX86 compiler doesn't like compiling for x64
	# ("no such file" opening a shared library), and vice-versa.
	# Work around it for now by using the strictly x86 compiler for x86, and x64 for x64.
	# NOTE: What about ARM?
	ifneq (,$(findstring x64,$(TargetArchMoniker)))
		VCCompilerToolsBinDir := $(VcCompilerToolsDir)\bin\HostX64
	else
		VCCompilerToolsBinDir := $(VcCompilerToolsDir)\bin\HostX86
	endif

	PATH := $(shell IFS=$$'\n'; cygpath "$(VCCompilerToolsBinDir)/$(TargetArchMoniker)"):$(PATH)
	PATH := $(PATH):$(shell IFS=$$'\n'; cygpath "$(VsInstallRoot)/Common7/IDE")
	INCLUDE := $(shell IFS=$$'\n'; cygpath -w "$(VcCompilerToolsDir)/include")
	LIB := $(shell IFS=$$'\n'; cygpath -w "$(VcCompilerToolsDir)/lib/$(TargetArchMoniker)")
	ifneq (,$(findstring uwp,$(PlatformSuffix)))
		LIB := $(shell IFS=$$'\n'; cygpath -w "$(LIB)/store")
	endif
    
	export INCLUDE := $(INCLUDE);$(WindowsSDKSharedIncludeDir);$(WindowsSDKUCRTIncludeDir);$(WindowsSDKUMIncludeDir);$(WindowsSDKWinRTIncludeDir)
	export LIB := $(LIB);$(WindowsSDKUCRTLibDir);$(WindowsSDKUMLibDir)
	export LIBPATH := $(LIBPATH);$(VcCompilerToolsStoreReferencesDir);$(WindowsSDKUnionMetadataDir)
	TARGET := $(TARGET_NAME)_libretro.dll
	PSS_STYLE :=2
	LDFLAGS += -DLL

  ENDIANNESS_DEFINES := -DLSB_FIRST -DBYTE_ORDER=LITTLE_ENDIAN -DALIGN_LONG

ifneq (,$(findstring windows_msvc2017_uwp_arm,$(platform)))
  #ENDIANNESS_DEFINES += -DALIGN_LONG
endif

# Windows MSVC 2010 x86
else ifeq ($(platform), windows_msvc2010_x86)
	CC  = cl.exe
	CXX = cl.exe

   HAVE_SYS_PARAM = 0
HAVE_CDROM = 1

PATH := $(shell IFS=$$'\n'; cygpath "$(VS100COMNTOOLS)../../VC/bin"):$(PATH)
PATH := $(PATH):$(shell IFS=$$'\n'; cygpath "$(VS100COMNTOOLS)../IDE")
LIB := $(shell IFS=$$'\n'; cygpath -w "$(VS100COMNTOOLS)../../VC/lib")
INCLUDE := $(shell IFS=$$'\n'; cygpath -w "$(VS100COMNTOOLS)../../VC/include")

WindowsSdkDir := $(shell reg query "HKLM\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v7.0A" -v "InstallationFolder" | grep -o '[A-Z]:\\.*')
WindowsSdkDir ?= $(shell reg query "HKLM\SOFTWARE\Microsoft\Microsoft SDKs\Windows\v7.1A" -v "InstallationFolder" | grep -o '[A-Z]:\\.*')
 
WindowsSdkDirInc := $(WindowsSdkDir)Include
WindowsSdkDirInc ?= $(WindowsSdkDir)Include

INCFLAGS_PLATFORM = -I"$(WindowsSdkDirInc)"
export INCLUDE := $(INCLUDE)
export LIB := $(LIB);$(WindowsSdkDir)\Lib
TARGET := $(TARGET_NAME)_libretro.dll
PSS_STYLE :=2
LDFLAGS += -DLL
LIBS =
# Windows MSVC 2005 x86
else ifeq ($(platform), windows_msvc2005_x86)
	CC  = cl.exe
	CXX = cl.exe

   HAVE_SYS_PARAM = 0
HAVE_CDROM = 1

PATH := $(shell IFS=$$'\n'; cygpath "$(VS80COMNTOOLS)../../VC/bin"):$(PATH)
PATH := $(PATH):$(shell IFS=$$'\n'; cygpath "$(VS80COMNTOOLS)../IDE")
INCLUDE := $(shell IFS=$$'\n'; cygpath "$(VS80COMNTOOLS)../../VC/include")
LIB := $(shell IFS=$$'\n'; cygpath -w "$(VS80COMNTOOLS)../../VC/lib")
BIN := $(shell IFS=$$'\n'; cygpath "$(VS80COMNTOOLS)../../VC/bin")

WindowsSdkDir := $(INETSDK)

export INCLUDE := $(INCLUDE);$(INETSDK)/Include;libretro/libretro-common/include/compat/msvc
export LIB := $(LIB);$(WindowsSdkDir);$(INETSDK)/Lib
TARGET := $(TARGET_NAME)_libretro.dll
PSS_STYLE :=2
LDFLAGS += -DLL
CFLAGS += -D_CRT_SECURE_NO_DEPRECATE
LIBS =

# Windows MSVC 2003 x86
else ifeq ($(platform), windows_msvc2003_x86)
	CC  = cl.exe
	CXX = cl.exe

PATH := $(shell IFS=$$'\n'; cygpath "$(VS71COMNTOOLS)../../Vc7/bin"):$(PATH)
PATH := $(PATH):$(shell IFS=$$'\n'; cygpath "$(VS71COMNTOOLS)../IDE")
INCLUDE := $(shell IFS=$$'\n'; cygpath "$(VS71COMNTOOLS)../../Vc7/include")
LIB := $(shell IFS=$$'\n'; cygpath -w "$(VS71COMNTOOLS)../../Vc7/lib")
BIN := $(shell IFS=$$'\n'; cygpath "$(VS71COMNTOOLS)../../Vc7/bin")

WindowsSdkDir := $(INETSDK)

export INCLUDE := $(INCLUDE);$(INETSDK)/Include;src/drivers/libretro/msvc/msvc-2005
export LIB := $(LIB);$(WindowsSdkDir);$(INETSDK)/Lib
TARGET := $(TARGET_NAME)_libretro.dll
PSS_STYLE :=2
LDFLAGS += -DLL
HAVE_SYS_PARAM = 0
CFLAGS += -D_CRT_SECURE_NO_DEPRECATE
   LIBS =

# Windows
else
   TARGET := $(TARGET_NAME)_libretro.dll
   CC ?= gcc
   CXX ?= g++
   SHARED := -shared -static-libgcc -static-libstdc++ -Wl,--version-script=$(CORE_DIR)/libretro/link.T -Wl,--no-undefined
   ENDIANNESS_DEFINES := -DLSB_FIRST -DBYTE_ORDER=LITTLE_ENDIAN
   PLATFORM_DEFINES := -DHAVE_ZLIB
   HAVE_CDROM = 1

endif

ifeq ($(SHARED_LIBVORBIS), 1)
	LDFLAGS += -lvorbisfile
endif

ifeq ($(DEBUG), 1)
ifneq (,$(findstring msvc,$(platform)))
	ifeq ($(STATIC_LINKING),1)
	CFLAGS += -MTd
	CXXFLAGS += -MTd
else
	CFLAGS += -MDd
	CXXFLAGS += -MDd
endif

CFLAGS += -Od -Zi -DDEBUG -D_DEBUG
CXXFLAGS += -Od -Zi -DDEBUG -D_DEBUG
	else
	CFLAGS += -O0 -g -DDEBUG
	CXXFLAGS += -O0 -g -DDEBUG
endif
else
ifneq (,$(findstring msvc,$(platform)))
ifeq ($(STATIC_LINKING),1)
	CFLAGS += -MT
	CXXFLAGS += -MT
else
	CFLAGS += -MD
	CXXFLAGS += -MD
endif

CFLAGS += -O2 -DNDEBUG
CXXFLAGS += -O2 -DNDEBUG
else
	CFLAGS += -O2 -DNDEBUG
	CXXFLAGS += -O2 -DNDEBUG
endif
endif

ifeq ($(SHARED_LIBVORBIS),)
   TREMOR_SRC_DIR := $(CORE_DIR)/core/tremor
endif

include $(CORE_DIR)/libretro/Makefile.common
libRetroReversingConsole = GenesisPlusGX
include ./libRetroReversing/Makefile.retroreversing

OBJECTS := $(SOURCES_C:.c=.o) $(SOURCES_CXX:.cpp=.o)

ifeq ($(LOGSOUND), 1)
   LIBRETRO_CFLAGS := -DLOGSOUND
endif

ifeq ($(SHARED_LIBVORBIS), 1)
	DEFINES := -DUSE_LIBVORBIS
else
	DEFINES := -DUSE_LIBTREMOR
endif

ifeq ($(HAVE_CHD), 1)
	DEFINES += -DUSE_LIBCHDR -DPACKAGE_VERSION=\"1.3.2\" -DFLAC_API_EXPORTS -DFLAC__HAS_OGG=0 -DHAVE_LROUND -DHAVE_STDINT_H -D_7ZIP_ST
endif


ifeq ($(HAVE_SYS_PARAM), 1)
DEFINES += -DHAVE_SYS_PARAM_H
else
DEFINES += -Dflac_max=MAX -Dflac_min=MIN -Dfseeko=fseek -Dftello=ftell
endif

ifeq ($(USE_PER_SOUND_CHANNELS_CONFIG), 1)
DEFINES += -DUSE_PER_SOUND_CHANNELS_CONFIG
endif

CFLAGS += $(fpic) $(DEFINES) $(CODE_DEFINES) $(FLAGS)
CXXFLAGS += $(fpic) $(DEFINES) $(CODE_DEFINES) $(FLAGS)

ifeq ($(FRONTEND_SUPPORTS_RGB565), 1)
   # if you have a new frontend that supports RGB565
   BPP_DEFINES = -DUSE_16BPP_RENDERING -DFRONTEND_SUPPORTS_RGB565
else
   BPP_DEFINES = -DUSE_15BPP_RENDERING
endif

ifeq ($(HAVE_CDROM), 1)
   LIBRETRO_CFLAGS += -DHAVE_CDROM
ifeq ($(CDROM_DEBUG), 1)
   LIBRETRO_CFLAGS += -DCDROM_DEBUG
endif
endif

LIBRETRO_CFLAGS += $(INCFLAGS) $(INCFLAGS_PLATFORM)
LIBRETRO_CFLAGS += $(BPP_DEFINES) \
		$(ENDIANNESS_DEFINES) \
		$(PLATFORM_DEFINES) \
		-D__LIBRETRO__ \
		-DM68K_OVERCLOCK_SHIFT=20 \
		-DZ80_OVERCLOCK_SHIFT=20 \
		-DHAVE_YM3438_CORE \
		-DHAVE_OPLL_CORE

ifneq (,$(findstring msvc,$(platform)))
   LIBRETRO_CFLAGS += -DINLINE="static _inline"
else
   LIBRETRO_CFLAGS += -DINLINE="static inline"
endif

OBJOUT   = -o
LINKOUT  = -o 

ifneq (,$(findstring msvc,$(platform)))
	OBJOUT = -Fo
	LINKOUT = -out:
ifeq ($(STATIC_LINKING),1)
	LD ?= lib.exe
	STATIC_LINKING=0
else
	LD = link.exe
endif
else
ifneq (,$(findstring uwp,$(PlatformSuffix)))
	LD = $(CXX)
else
	LD = $(CC)
endif
endif

ifeq ($(platform), theos_ios)
COMMON_FLAGS := $(COMMON_DEFINES) $(INCFLAGS) -I$(THEOS_INCLUDE_PATH) -Wno-error
$(LIBRARY_NAME)_CFLAGS += $(CFLAGS) $(LIBRETRO_CFLAGS) $(COMMON_FLAGS)
${LIBRARY_NAME}_FILES = $(SOURCES_C) $(SOURCES_CXX)
${LIBRARY_NAME}_LIBRARIES = m z
include $(THEOS_MAKE_PATH)/library.mk
else
all: $(TARGET)

%.o: %.cpp
	$(CXX) $(OBJOUT)$@ -c $< $(CXXFLAGS) $(LIBRETRO_CFLAGS)

%.o: %.c
	$(CC) $(OBJOUT)$@ -c $< $(CFLAGS) $(LIBRETRO_CFLAGS)

$(TARGET): $(OBJECTS)
ifeq ($(STATIC_LINKING), 1)
	$(AR) rcs $@ $(OBJECTS)
else
	$(LD) $(LINKOUT)$(TARGET) $(fpic) $(OBJECTS) $(LDFLAGS) $(SHARED) $(LIBS)
endif
  
clean-objs:
	rm -f $(OBJECTS)

clean:
	rm -f $(OBJECTS)
	rm -f $(TARGET)

.PHONY: clean clean-objs
endif

print-%:
	@echo '$*=$($*)'
