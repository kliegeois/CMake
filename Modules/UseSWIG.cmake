# - SWIG module for CMake
# Defines the following macros:
#   SWIG_ADD_MODULE(name language [ files ])
#     - Define swig module with given name and specified language
#   SWIG_LINK_LIBRARIES(name [ libraries ])
#     - Link libraries to swig module
# All other macros are for internal use only.
# To get the actual name of the swig module,
# use: ${SWIG_MODULE_name_REAL_NAME}.
# Set Source files properties such as CPLUSPLUS and SWIG_FLAGS to specify
# special behavior of SWIG. Also global CMAKE_SWIG_FLAGS can be used to add
# special flags to all swig calls.
# Another special variable is CMAKE_SWIG_OUTDIR, it allows one to specify 
# where to write all the swig generated module (swig -outdir option)
# The name-specific variable SWIG_MODULE_<name>_EXTRA_DEPS may be used
# to specify extra dependencies for the generated modules.

SET(SWIG_CXX_EXTENSION "cpp")
SET(SWIG_EXTRA_LIBRARIES "")

SET(SWIG_PYTHON_EXTRA_FILE_EXTENSION "py")

#
# For given swig module initialize variables associated with it
#
MACRO(SWIG_MODULE_INITIALIZE name module language)
  STRING(TOUPPER "${language}" swig_uppercase_language)
  STRING(TOLOWER "${language}" swig_lowercase_language)
  SET(SWIG_MODULE_${name}_LANGUAGE "${swig_uppercase_language}")
  SET(SWIG_MODULE_${name}_SWIG_LANGUAGE_FLAG "${swig_lowercase_language}")

  IF("x${SWIG_MODULE_${name}_LANGUAGE}x" MATCHES "^xUNKNOWNx$")
    MESSAGE(FATAL_ERROR "SWIG Error: Language \"${language}\" not found")
  ENDIF("x${SWIG_MODULE_${name}_LANGUAGE}x" MATCHES "^xUNKNOWNx$")

  IF(SWIG_MODULE_${name}_MODULE)
    SET(SWIG_MODULE_${name}_REAL_NAME "${SWIG_MODULE_${name}_MODULE}")
  ELSE(SWIG_MODULE_${name}_MODULE)
    SET(SWIG_MODULE_${name}_REAL_NAME "${module}")
  ENDIF(SWIG_MODULE_${name}_MODULE)
  IF("x${SWIG_MODULE_${name}_LANGUAGE}x" MATCHES "^xPYTHONx$")
    SET(SWIG_MODULE_${name}_REAL_NAME "_${SWIG_MODULE_${name}_REAL_NAME}")
  ENDIF("x${SWIG_MODULE_${name}_LANGUAGE}x" MATCHES "^xPYTHONx$")
  IF("x${SWIG_MODULE_${name}_LANGUAGE}x" MATCHES "^xPERLx$")
    SET(SWIG_MODULE_${name}_EXTRA_FLAGS "-shadow")
  ENDIF("x${SWIG_MODULE_${name}_LANGUAGE}x" MATCHES "^xPERLx$")
ENDMACRO(SWIG_MODULE_INITIALIZE)

#
# For a given swig interface file, determine the module name and the
# list of parent packages from the SWIG %module directive.
#
MACRO(SWIG_MODULE_GET_OUTDIR_AND_MODULE swigfile outdir module)
  SET(${outdir} "")
  SET(${module} "")
  FILE(READ "${swigfile}" swig_contents)
  STRING(REGEX MATCH "%module *(\\([^\\)]*\\))? +[A-Za-z0-9_]+"
    swig_module_match "${swig_contents}")
  IF(swig_module_match)
    STRING(REGEX REPLACE "%module *\\(([^\\)]*)\\)" "\\1"
      swig_module_options ${swig_module_match})
    IF(swig_module_options)
      STRING(REGEX REPLACE "package *= *\"([^\"]*).*" "\\1"
	swig_package ${swig_module_options})
      IF(swig_package)
	STRING(REPLACE "." "/" ${outdir} ${swig_package})
      ENDIF(swig_package)
    ENDIF(swig_module_options)
    STRING(REGEX REPLACE "%module *(\\([^\\)]*\\))? +([A-Za-z0-9_]+)" "\\2"
      ${module} ${swig_module_match})
  ENDIF(swig_module_match)
ENDMACRO(SWIG_MODULE_GET_OUTDIR_AND_MODULE)

#
# For a given language, input file, and output file, determine extra files that
# will be generated. This is internal swig macro.
#
MACRO(SWIG_GET_EXTRA_OUTPUT_FILES language outfiles infile outdir module)
  SET(${outfiles})
  FOREACH(it ${SWIG_${language}_EXTRA_FILE_EXTENSION})
    set(${outfiles} ${${outfiles}}
      ${outdir}/${module}.${it})
  ENDFOREACH(it)
ENDMACRO(SWIG_GET_EXTRA_OUTPUT_FILES)

#
# Use "swig -MM" to obtain a list of dependencies for the swig module
# and use it to set SWIG_MODULE_${name}_EXTRA_DEPS.
#
MACRO(SWIG_GET_DEPENDENCIES name)
  # This execute_process has three phases: (1) run swig -MM to obtain
  # the dependencies, (2) pipe the results to sed to delete the first
  # line (which is the wrapper file name), and (3) pipe those results
  # to sed again to convert the continuation character to a semicolon.
  GET_SOURCE_FILE_PROPERTY(swig_source_file_generated ${name} GENERATED)
  IF(swig_source_file_generated)
    EXECUTE_PROCESS(COMMAND ${SWIG_EXECUTABLE} -MM ${swig_special_flags}
      -${SWIG_MODULE_${name}_SWIG_LANGUAGE_FLAG} ${swig_source_file_flags} ${CMAKE_SWIG_FLAGS}
      ${swig_extra_flags} ${swig_include_dirs} ${swig_source_file_fullname}
      COMMAND sed "1 d"
      COMMAND sed "s/ \\\\/;/"
      OUTPUT_VARIABLE swig_dependencies
      )
    # Loop over ${swig_dependencies} to generate a whitespace-stripped
    # SWIG_MODULE_${name}_EXTRA_DEPS
    SET(SWIG_MODULE_${name}_EXTRA_DEPS "")
    FOREACH(it ${swig_dependencies})
      STRING(STRIP ${it} dependency)
      SET(SWIG_MODULE_${name}_EXTRA_DEPS ${SWIG_MODULE_${name}_EXTRA_DEPS} ${dependency})
    ENDFOREACH(it)
  ENDIF(swig_source_file_generated)
ENDMACRO(SWIG_GET_DEPENDENCIES)

#
# Take swig (*.i) file and add proper custom commands for it
#
MACRO(SWIG_ADD_SOURCE_TO_MODULE name outfiles infile outdir module)
  SET(swig_full_infile ${infile})
  GET_FILENAME_COMPONENT(swig_source_file_path "${infile}" PATH)
  GET_FILENAME_COMPONENT(swig_source_file_name "${infile}" NAME)
  STRING(REGEX REPLACE "(.*)\\.i$" "\\1" swig_source_file_name_we ${swig_source_file_name})
  GET_SOURCE_FILE_PROPERTY(swig_source_file_generated ${infile} GENERATED)
  GET_SOURCE_FILE_PROPERTY(swig_source_file_cplusplus ${infile} CPLUSPLUS)
  GET_SOURCE_FILE_PROPERTY(swig_source_file_flags ${infile} SWIG_FLAGS)
  IF("${swig_source_file_flags}" STREQUAL "NOTFOUND")
    SET(swig_source_file_flags "")
  ENDIF("${swig_source_file_flags}" STREQUAL "NOTFOUND")
  SET(swig_source_file_fullname "${infile}")
  IF(${swig_source_file_path} MATCHES "^${CMAKE_CURRENT_SOURCE_DIR}")
    STRING(REGEX REPLACE 
      "^${CMAKE_CURRENT_SOURCE_DIR}" ""
      swig_source_file_relative_path
      "${swig_source_file_path}")
  ELSE(${swig_source_file_path} MATCHES "^${CMAKE_CURRENT_SOURCE_DIR}")
    IF(${swig_source_file_path} MATCHES "^${CMAKE_CURRENT_BINARY_DIR}")
      STRING(REGEX REPLACE 
        "^${CMAKE_CURRENT_BINARY_DIR}" ""
        swig_source_file_relative_path
        "${swig_source_file_path}")
      SET(swig_source_file_generated 1)
    ELSE(${swig_source_file_path} MATCHES "^${CMAKE_CURRENT_BINARY_DIR}")
      SET(swig_source_file_relative_path "${swig_source_file_path}")
      IF(swig_source_file_generated)
        SET(swig_source_file_fullname "${CMAKE_CURRENT_BINARY_DIR}/${infile}")
      ELSE(swig_source_file_generated)
        SET(swig_source_file_fullname "${CMAKE_CURRENT_SOURCE_DIR}/${infile}")
      ENDIF(swig_source_file_generated)
    ENDIF(${swig_source_file_path} MATCHES "^${CMAKE_CURRENT_BINARY_DIR}")
  ENDIF(${swig_source_file_path} MATCHES "^${CMAKE_CURRENT_SOURCE_DIR}")

  SET(swig_generated_file_fullname
    "${CMAKE_CURRENT_BINARY_DIR}")
  IF(swig_source_file_relative_path)
    SET(swig_generated_file_fullname
      "${swig_generated_file_fullname}/${swig_source_file_relative_path}")
  ENDIF(swig_source_file_relative_path)
  SWIG_GET_EXTRA_OUTPUT_FILES(${SWIG_MODULE_${name}_LANGUAGE}
    swig_extra_generated_files
    "${infile}"
    "${outdir}"
    "${module}")
  SET(swig_generated_file_fullname
    "${swig_generated_file_fullname}/${swig_source_file_name_we}")
  # Add the language into the name of the file (i.e. TCL_wrap).  This
  # allows for the same .i file to be wrapped into different languages
  SET(swig_generated_file_fullname
    "${swig_generated_file_fullname}${SWIG_MODULE_${name}_LANGUAGE}_wrap")

  IF(swig_source_file_cplusplus)
    SET(swig_generated_file_fullname
      "${swig_generated_file_fullname}.${SWIG_CXX_EXTENSION}")
  ELSE(swig_source_file_cplusplus)
    SET(swig_generated_file_fullname
      "${swig_generated_file_fullname}.c")
  ENDIF(swig_source_file_cplusplus)

  GET_DIRECTORY_PROPERTY(cmake_include_directories INCLUDE_DIRECTORIES)
  SET(swig_include_dirs)
  FOREACH(it ${cmake_include_directories})
    SET(swig_include_dirs ${swig_include_dirs} "-I${it}")
  ENDFOREACH(it)

  SET(swig_special_flags)
  # Default is c, so add c++ flag if it is c++
  IF(swig_source_file_cplusplus)
    SET(swig_special_flags ${swig_special_flags} "-c++")
  ENDIF(swig_source_file_cplusplus)
  SET(swig_extra_flags)
  IF(SWIG_MODULE_${name}_EXTRA_FLAGS)
    SET(swig_extra_flags ${swig_extra_flags} ${SWIG_MODULE_${name}_EXTRA_FLAGS})
  ENDIF(SWIG_MODULE_${name}_EXTRA_FLAGS)

  SWIG_GET_DEPENDENCIES(${name})

  ADD_CUSTOM_COMMAND(
    OUTPUT "${swig_generated_file_fullname}" ${swig_extra_generated_files}
    COMMAND "${SWIG_EXECUTABLE}"
    ARGS "-${SWIG_MODULE_${name}_SWIG_LANGUAGE_FLAG}"
    ${swig_source_file_flags}
    ${CMAKE_SWIG_FLAGS}
    -outdir ${outdir}
    ${swig_special_flags}
    ${swig_extra_flags}
    ${swig_include_dirs}
    -o "${swig_generated_file_fullname}"
    "${swig_source_file_fullname}"
    MAIN_DEPENDENCY "${swig_source_file_fullname}"
    DEPENDS ${SWIG_MODULE_${name}_EXTRA_DEPS}
    COMMENT "Swig source ${swig_source_file_fullname}") 
  SET_SOURCE_FILES_PROPERTIES("${swig_generated_file_fullname}" ${swig_extra_generated_files}
    PROPERTIES GENERATED 1)
  SET(${outfiles} "${swig_generated_file_fullname}" ${swig_extra_generated_files})
ENDMACRO(SWIG_ADD_SOURCE_TO_MODULE)

#
# Create Swig module
#
MACRO(SWIG_ADD_MODULE name language source outdir module)
  # Obtain the *.i and other sources
  SET(swig_dot_i_sources ${source})
  SET(swig_other_sources)
  FOREACH(it ${ARGN})
    IF(${it} MATCHES ".*\\.i$")
      SET(swig_dot_i_sources ${swig_dot_i_sources} "${it}")
    ELSE(${it} MATCHES ".*\\.i$")
      SET(swig_other_sources ${swig_other_sources} "${it}")
    ENDIF(${it} MATCHES ".*\\.i$")
  ENDFOREACH(it)

  SWIG_MODULE_INITIALIZE(${name} ${module} ${language})

  SET(swig_generated_sources)
  SET(CMAKE_SWIG_OUTDIR "${outdir}")
  FOREACH(it ${swig_dot_i_sources})
    SWIG_ADD_SOURCE_TO_MODULE(${name} swig_generated_source ${it} ${outdir} ${module})
    SET(swig_generated_sources ${swig_generated_sources} "${swig_generated_source}")
  ENDFOREACH(it)
  SET(CMAKE_SWIG_OUTDIR "")
  GET_DIRECTORY_PROPERTY(swig_extra_clean_files ADDITIONAL_MAKE_CLEAN_FILES)
  SET_DIRECTORY_PROPERTIES(PROPERTIES
    ADDITIONAL_MAKE_CLEAN_FILES "${swig_extra_clean_files};${swig_generated_sources}")
  ADD_LIBRARY(${name}
    MODULE
    ${swig_generated_sources}
    ${swig_other_sources})
  SET_TARGET_PROPERTIES(${name}
    PROPERTIES PREFIX "")
  IF(NOT "${outdir}" STREQUAL "")
    SET_TARGET_PROPERTIES(${name} PROPERTIES
      LIBRARY_OUTPUT_DIRECTORY ${outdir})
  ENDIF(NOT "${outdir}" STREQUAL "")
  SET_TARGET_PROPERTIES(${name} PROPERTIES
    OUTPUT_NAME _${module})
ENDMACRO(SWIG_ADD_MODULE)

#
# Like TARGET_LINK_LIBRARIES but for swig modules
#
MACRO(SWIG_LINK_LIBRARIES name)
  TARGET_LINK_LIBRARIES(${name} ${ARGN})
ENDMACRO(SWIG_LINK_LIBRARIES name)

