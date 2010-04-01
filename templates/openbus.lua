-- WARNING: this file will be included on installer.lua and some variables
-- like CONFIG, ERROR are filled there!
-- All global variables in this file, will become global in installer.lua too!
Types = {}
Types.vector = {}
setmetatable(Types.vector,{
__call = function(self,t,save)
  local count = 1
  while (true) do
    print(CONFIG,"Property name: ".. t.name)
    print(CONFIG,"Informe o valor do vetor")
    io.write("> ")
    local var = io.read("*l")
    if tonumber(var) then var = tonumber(var) end
    if not save[t.name] then save[t.name] = {} end
    table.insert(save[t.name],var)
    
    print(CONFIG,"Deseja informar outro elemento para o vetor '" .. t.name ..
        "'? sim ou nao?")
    io.write("> ")
    if not string.upper(io.read("*l")):find("SIM") then break end
    count = count + 1
  end
end
})

Types.ldapHosts = {
  name = "Nome do servidor LDAP",
  port = "Porta do servidor LDAP",
}
setmetatable(Types.ldapHosts,{
__call =  function(self,t,save)
  local count = 1
  if not save[t.name] then save[t.name] = {} end
  -- Repeat until an user says 'stop'
  while (true) do
    local tmp = {}
    -- For all keys in self table: ask the value of 'key' printing the 'msg'
    for key, msg in pairs(self) do
      print(CONFIG,"Property name: ".. t.name .." index: ".. count)
      print(CONFIG,msg)
      io.write("> ")
      local var = io.read("*l")
      if tonumber(var) then var = tonumber(var) end
      tmp[key] = var
    end
    -- Saving the table with the element of the list (ldapHosts)
    table.insert(save[t.name],tmp)
    -- Do you wish continue or not?
    print(CONFIG,"Deseja informar outro elemento para a lista '" .. t.name .. 
        "'? sim ou nao?")
    io.write("> ")
    if not string.upper(io.read("*l")):find("SIM") then break end
    count = count + 1
  end
end
})

messages = {
  { name = "hostName", 
    msg = "FQDN da máquina onde o Serviço de Acesso executará",
    type = "string",
    value = "localhost",
  },
  { name = "hostPort",
    msg = "Porta para o Serviço de Acesso",
    type = "number",
    value = 2089,
  },
  { name = "oilVerboseLevel",
    msg = "Nível de verbosidade do ORB OiL [de 0 a 5]",
    type = "number",
    value = 5,
  },
  { name = "logLevel",
    msg = "Nível de verbosidade do log do OpenBus [de 0 a 3]",
    type = "number",
    value = 3,
  },
  { name = "ldapHosts",
    msg = "Lista dos servidores LDAP com portas",
    type = "list",
    check = Types.ldapHosts,
    value = {name = "segall.tecgraf.puc-rio.br", port = 389,},
  },
  { name = "ldapSuffixes",
    msg = "Sufixos de busca no servidor LDAP",
    type = "list",
    check = Types.vector,
    value = { "" },
  },
  { name = "administrators",
    msg = "Administradores do barramento.",
    type = "list",
    check = Types.vector,
    value = { },
  }
}

configure_action = function(answers, path, util)
  -- Loading original OpenBus file config (its loads for tables)
  local acsConfFile = path.."/data/conf/AccessControlServerConfiguration.lua"
  assert(loadfile(acsConfFile))()
  AccessControlServerConfiguration.hostName = answers.hostName
  AccessControlServerConfiguration.hostPort = answers.hostPort
  AccessControlServerConfiguration.ldapHosts = answers.ldapHosts
  AccessControlServerConfiguration.ldapSuffixes = answers.ldapSuffixes
  AccessControlServerConfiguration.administrators = answers.administrators
  AccessControlServerConfiguration.oilVerboseLevel = answers.oilVerboseLevel
  AccessControlServerConfiguration.logLevel = answers.logLevel

  AccessControlServerConfiguration.lease = 60
  AccessControlServerConfiguration.validators = {
      "core.services.accesscontrol.LDAPLoginPasswordValidator",
      "core.services.accesscontrol.TestLoginPasswordValidator",
  }
  AccessControlServerConfiguration.certificatesDirectory = "certificates"
  AccessControlServerConfiguration.privateKeyFile =
      "certificates/AccessControlService.key"
  AccessControlServerConfiguration.databaseDirectory = "credentials"


  local rgsConfFile = path.."/data/conf/RegistryServerConfiguration.lua"
  assert(loadfile(rgsConfFile))()
  RegistryServerConfiguration.accessControlServerHostName = answers.hostName
  RegistryServerConfiguration.accessControlServerHostPort = answers.hostPort

  RegistryServerConfiguration.registryServerHostName = answers.hostName
  RegistryServerConfiguration.registryServerHostPort = answers.hostPort - 30
  
  RegistryServerConfiguration.privateKeyFile =
      "certificates/RegistryService.key"
  RegistryServerConfiguration.accessControlServiceCertificateFile =
      "certificates/AccessControlService.crt"
  RegistryServerConfiguration.databaseDirectory = "offers"
  RegistryServerConfiguration.administrators = answers.administrators
  RegistryServerConfiguration.oilVerboseLevel = answers.oilVerboseLevel
  RegistryServerConfiguration.logLevel = answers.logLevel


  local sesConfFile = path.."/data/conf/SessionServerConfiguration.lua"
  assert(loadfile(sesConfFile))()
  -- this configuration depends of AccessControlServerConfiguration
  SessionServerConfiguration.accessControlServerHostName = answers.hostName
  SessionServerConfiguration.accessControlServerHostPort = answers.hostPort

  SessionServerConfiguration.sessionServerHostName = answers.hostName
  SessionServerConfiguration.sessionServerHostPort = answers.hostPort - 60

  SessionServerConfiguration.privateKeyFile = "certificates/SessionService.key"
  SessionServerConfiguration.accessControlServiceCertificateFile =
      "certificates/AccessControlService.crt"
  SessionServerConfiguration.logLevel = answers.logLevel
  SessionServerConfiguration.oilVerboseLevel = answers.oilVerboseLevel


  -- Persisting the configurations to temporary tree where the tarball was extracted
  util.serialize_table(acsConfFile,AccessControlServerConfiguration,
      "AccessControlServerConfiguration")
  util.serialize_table(rgsConfFile,RegistryServerConfiguration,
      "RegistryServerConfiguration")
  util.serialize_table(sesConfFile,SessionServerConfiguration,
      "SessionServerConfiguration")
  return true
end
