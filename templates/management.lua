

messages = {
  { name = "admLogin", 
    msg = "Login do administrador",
    type = "string",
    value = "",
  },
}

configure_action = function(answers, tempdir, util)
  if answers.admLogin == "" then
    print "[ERRO] Login do administrador não foi informado"
    return false
  end

  os.execute(
      tempdir .. "/tools/shell/subscribe-services.sh " .. answers.admLogin 
      .. " " .. tempdir
      )
  return true
end
