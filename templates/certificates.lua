

messages = {
}

configure_action = function(answers, path, util)
  local installPath =  path
  local openSSLGenerate = path .. "/tools/shell/openssl-generate.ksh "
  -- Criando chaves dos servi�os b�sicos.
  os.execute(
      "cd " .. installPath .. "/tools/management;" .. 
      openSSLGenerate .. "AccessControlService;" ..
      openSSLGenerate .. "RegistryService;" ..
      openSSLGenerate .. "SessionService;"
      )
  
  -- Movendo as chaves privadas para o diret�rio correto.
  os.execute(
      "cd " .. installPath .. "/tools/management;" ..
      "mkdir " .. installPath .. "/data/certificates;" ..
      "mv *.key " .. installPath .. "/data/certificates;"
      )

  -- Criando chaves dos demos.
  
  -- Criando chaves para os testes.
  
  return true
end
