################################################################################
#
# robin_xml
#
################################################################################

ROBIN_XML_VERSION ?= 4db2b64c86720b95d8cd938e62be22456845859b
ROBIN_XML_SITE = $(call github,robin903230,robin-xml,$(ROBIN_XML_VERSION))

ROBIN_XML_LICENSE = Apache-2.0
ROBIN_XML_DEPENDENCIES = hostboot openpower-mrw common-p8-xml

ROBIN_XML_INSTALL_IMAGES = YES
ROBIN_XML_INSTALL_TARGET = YES

MRW_SCRATCH=$(STAGING_DIR)/openpower_mrw_scratch
MRW_HB_TOOLS=$(STAGING_DIR)/hostboot_build_images

# Defines for BIOS metadata creation
BIOS_SCHEMA_FILE = $(MRW_HB_TOOLS)/bios.xsd
ROBIN_BIOS_XML_CONFIG_FILE = $(MRW_SCRATCH)/$(BR2_ROBIN_BIOS_XML_FILENAME)
BIOS_XML_METADATA_FILE = \
    $(MRW_HB_TOOLS)/$(BR2_OPENPOWER_CONFIG_NAME)_bios_metadata.xml
PETITBOOT_XSLT_FILE = $(MRW_HB_TOOLS)/bios_metadata_petitboot.xslt
PETITBOOT_BIOS_XML_METADATA_FILE = \
    $(MRW_HB_TOOLS)/$(BR2_OPENPOWER_CONFIG_NAME)_bios_metadata_petitboot.xml
PETITBOOT_BIOS_XML_METADATA_INITRAMFS_FILE = \
    $(TARGET_DIR)/usr/share/bios_metadata.xml

define ROBIN_XML_BUILD_CMDS
        # copy the robin xml where the common lives
        bash -c 'mkdir -p $(MRW_SCRATCH) && cp -r $(@D)/* $(MRW_SCRATCH)'

        # generate the system mrw xml
        perl -I $(MRW_HB_TOOLS) \
        $(MRW_HB_TOOLS)/processMrw.pl -x $(MRW_SCRATCH)/robin.xml
        
        # merge in any system specific attributes, hostboot attributes
        $(MRW_HB_TOOLS)/mergexml.sh $(MRW_SCRATCH)/$(BR2_ROBIN_SYSTEM_XML_FILENAME) \
            $(MRW_HB_TOOLS)/attribute_types.xml \
            $(MRW_HB_TOOLS)/attribute_types_hb.xml \
            $(MRW_HB_TOOLS)/attribute_types_openpower.xml \
            $(MRW_HB_TOOLS)/target_types_merged.xml \
            $(MRW_HB_TOOLS)/target_types_hb.xml \
            $(MRW_HB_TOOLS)/target_types_openpower.xml \
            $(MRW_SCRATCH)/$(BR2_ROBIN_MRW_XML_FILENAME) > $(MRW_HB_TOOLS)/temporary_hb.hb.xml;

        # creating the targeting binary
        $(MRW_HB_TOOLS)/xmltohb.pl  \
            --hb-xml-file=$(MRW_HB_TOOLS)/temporary_hb.hb.xml \
            --fapi-attributes-xml-file=$(MRW_HB_TOOLS)/fapiattrs.xml \
            --src-output-dir=none \
            --img-output-dir=$(MRW_HB_TOOLS)/ \
            --vmm-consts-file=$(MRW_HB_TOOLS)/vmmconst.h --noshort-enums \
            --bios-xml-file=$(ROBIN_BIOS_XML_CONFIG_FILE) \
            --bios-schema-file=$(BIOS_SCHEMA_FILE) \
            --bios-output-file=$(BIOS_XML_METADATA_FILE)

        # Transform BIOS XML into Petitboot specific BIOS XML via the schema
        xsltproc -o \
            $(PETITBOOT_BIOS_XML_METADATA_FILE) \
            $(PETITBOOT_XSLT_FILE) \
            $(BIOS_XML_METADATA_FILE)
endef

define ROBIN_XML_INSTALL_IMAGES_CMDS
        mv $(MRW_HB_TOOLS)/targeting.bin $(MRW_HB_TOOLS)/$(BR2_OPENPOWER_TARGETING_BIN_FILENAME)
endef

define ROBIN_XML_INSTALL_TARGET_CMDS
        # Install Petitboot specific BIOS XML into initramfs's usr/share/ dir
        $(INSTALL) -D -m 0644 \
            $(PETITBOOT_BIOS_XML_METADATA_FILE) \
            $(PETITBOOT_BIOS_XML_METADATA_INITRAMFS_FILE)
endef

$(eval $(generic-package))
