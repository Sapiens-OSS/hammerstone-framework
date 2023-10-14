local patch = {
    operations = {
        [1] = { type = "localFunctionToGlobal", moduleName = "serverSapienAI", functionName = "createGeneralOrder"}
    }
}

return patch