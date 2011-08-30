

#
# Based on ParaView/VTK/Utilities/vtkTclTest2Py/CMakeLists.txt and
#          ParaView/VTK/Wrapping/Python/CMakeLists.txt
#

INCLUDE(${CTK_CMAKE_DIR}/ctkMacroParseArguments.cmake)

#! \ingroup CMakeAPI
MACRO(ctkMacroCompilePythonScript)
  ctkMacroParseArguments(MY
    "TARGET_NAME;SCRIPTS;RESOURCES;SOURCE_DIR;DESTINATION_DIR;INSTALL_DIR"
    "NO_INSTALL_SUBDIR"
    ${ARGN}
    )

  FIND_PACKAGE(PythonInterp REQUIRED)
  FIND_PACKAGE(PythonLibs REQUIRED)

  # Extract python lib path
  get_filename_component(PYTHON_LIBRARY_PATH ${PYTHON_LIBRARY} PATH)
  
  # Sanity checks
  FOREACH(varname TARGET_NAME SCRIPTS DESTINATION_DIR INSTALL_DIR)
    IF(NOT DEFINED MY_${varname})
      MESSAGE(FATAL_ERROR "${varname} is mandatory")
    ENDIF()
  ENDFOREACH()

  IF(NOT DEFINED MY_SOURCE_DIR)
    SET(MY_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
  ENDIF()

  # Since 'add_custom_command' doesn't play nicely with path having multiple
  # consecutive slashes. Let's make sure there are no trailing slashes.
  get_filename_component(MY_SOURCE_DIR ${MY_SOURCE_DIR} REALPATH)
  get_filename_component(MY_DESTINATION_DIR ${MY_DESTINATION_DIR} REALPATH)
  get_filename_component(MY_INSTALL_DIR ${MY_INSTALL_DIR} REALPATH)

  SET(input_python_files)
  SET(copied_python_files)
  FOREACH(file ${MY_SCRIPTS})
    # Append "py" extension if needed
    get_filename_component(file_ext ${file} EXT)
    IF(NOT "${file_ext}" MATCHES "py")
      SET(file "${file}.py")
    ENDIF()

    SET(src "${MY_SOURCE_DIR}/${file}")
    SET(tgt "${MY_DESTINATION_DIR}/${file}")
    IF(IS_ABSOLUTE ${file})
      SET(src ${file})
      file(RELATIVE_PATH tgt_file ${CMAKE_CURRENT_BINARY_DIR} ${file})
      SET(tgt "${MY_DESTINATION_DIR}/${tgt_file}")
    ENDIF()

    LIST(APPEND input_python_files ${src})
    ADD_CUSTOM_COMMAND(DEPENDS ${src}
                        COMMAND ${CMAKE_COMMAND} -E copy ${src} ${tgt}
                        OUTPUT ${tgt}
                        COMMENT "Copying python script: ${file}")
    LIST(APPEND copied_python_files ${tgt})
  ENDFOREACH()
  
  ADD_CUSTOM_TARGET(Copy${MY_TARGET_NAME}PythonFiles DEPENDS ${input_python_files} ${copied_python_files})
  
  # Byte compile the Python files.
  SET(compile_all_script "${CMAKE_CURRENT_BINARY_DIR}/compile_${MY_TARGET_NAME}_python_scripts.py")
  
  # Generate compile_${MY_TARGET_NAME}_python_scripts.py
  FILE(WRITE ${compile_all_script} "
#
# Generated by ctkMacroCompilePythonScript CMAKE macro
#

# Based on paraview/VTK/Wrapping/Python/compile_all_vtk.py.in

import compileall
compileall.compile_dir('@MY_DESTINATION_DIR@')
file = open('@CMAKE_CURRENT_BINARY_DIR@/python_compile_@MY_TARGET_NAME@_complete', 'w')
file.write('Done')
")

  # Configure cmake script associated with the custom command
  # required to properly update the library path with PYTHON_LIBRARY_PATH
  SET(compile_all_cmake_script "${CMAKE_CURRENT_BINARY_DIR}/compile_${MY_TARGET_NAME}_python_scripts.cmake")
  FILE(WRITE ${compile_all_cmake_script} "
#
# Generated by ctkMacroCompilePythonScript CMAKE macro
#

IF(WIN32)
    SET(ENV{PATH} \"@PYTHON_LIBRARY_PATH@;\$ENV{PATH}\")
ELSEIF(APPLE)
  SET(ENV{DYLD_LIBRARY_PATH} \"@PYTHON_LIBRARY_PATH@:\$ENV{DYLD_LIBRARY_PATH}\")
ELSE()
  SET(ENV{LD_LIBRARY_PATH} \"@PYTHON_LIBRARY_PATH@:\$ENV{LD_LIBRARY_PATH}\")
ENDIF()

EXECUTE_PROCESS(
  COMMAND \"@PYTHON_EXECUTABLE@\" \"@compile_all_script@\"
  )
")

  ADD_CUSTOM_COMMAND(
    COMMAND ${CMAKE_COMMAND} -P ${compile_all_cmake_script}
    DEPENDS ${copied_python_files}  ${compile_all_script}
    OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/python_compile_${MY_TARGET_NAME}_complete"
    COMMENT "Compiling python scripts: ${MY_TARGET_NAME}"
    )

  ADD_CUSTOM_TARGET(Compile${MY_TARGET_NAME}PythonFiles ALL
    DEPENDS 
      ${CMAKE_CURRENT_BINARY_DIR}/python_compile_${MY_TARGET_NAME}_complete
      ${compile_all_script}
      )
      
  IF(DEFINED MY_RESOURCES)
    SET(resource_input_files)
    SET(copied_resource_files)
    FOREACH(file ${MY_RESOURCES})
      SET(src "${CMAKE_CURRENT_SOURCE_DIR}/${file}")
      SET(tgt "${MY_DESTINATION_DIR}/${file}")
      
      LIST(APPEND resource_input_files ${src})
      ADD_CUSTOM_COMMAND(DEPENDS ${src}
                          COMMAND ${CMAKE_COMMAND} -E copy ${src} ${tgt}
                          OUTPUT ${tgt}
                          COMMENT "Copying python resource: ${file}")
      LIST(APPEND copied_resource_files ${tgt})
    ENDFOREACH()
    ADD_CUSTOM_TARGET(Copy${MY_TARGET_NAME}PythonResourceFiles ALL
      DEPENDS
        ${resource_input_files} 
        ${copied_resource_files}
        )
  ENDIF()

  set(MY_DIRECTORY_TO_INSTALL ${MY_DESTINATION_DIR})
  if(MY_NO_INSTALL_SUBDIR)
    set(MY_DIRECTORY_TO_INSTALL ${MY_DESTINATION_DIR}/)
  endif()

  # Install python module / resources directory
  INSTALL(DIRECTORY "${MY_DIRECTORY_TO_INSTALL}"
    DESTINATION "${MY_INSTALL_DIR}" COMPONENT Runtime
    USE_SOURCE_PERMISSIONS)
       
ENDMACRO()

