WebBanking{
	version = 1.0,
	url = "https://www.primecard.de/",
	services = { "I.B.E Primecard" },
	description = "Umsätze und Kontostand der I.B.E Primecard "
}

local connection = Connection()

local uname

function SupportsBank (protocol, bankCode)
  return protocol == ProtocolWebBanking and bankCode == "I.B.E Primecard"
end

function InitializeSession (protocol, bankCode, username, reserved, password)
  html = HTML(connection:get(url .. "my/"))

  html:xpath("//input[@name='ccnumber']"):attr("value", username)
  html:xpath("//input[@name='ccaccess']"):attr("value", password)
  e=html:xpath("//*[@id='loginButton']")
  _, _, postContent, postContentType = e:click()

  p_value = MM.sha512(password)
  postContent = postContent .. "&p=" .. p_value

  html = HTML(connection:request("POST", url .. "includes/login_ma.php", postContent, postContentType))
  local error = html:xpath("//*[@id='errorLine']")
	if error:length() > 0 then
    return LoginFailed
  end
  uname=username
  return nil
end

function EndSession()
end

function ListAccounts (knownAccounts)
  local html = HTML(connection:get(url .. "my/overview.php"))
  n=html:xpath("//*[@id='mainBox']/div/div[2]/div[1]/table/tbody/tr/td[2]/h3"):text()
  name=n:sub(n:find("für")+4)
  local account = {
    name = "IBE Card "..name,
    accountNumber = uname,
    currency = "EUR",
    type = AccountTypeCreditCard
  }
  return {account}
end

function RefreshAccount (account, since)
  json=connection:get(url .. '/includes/pctrl_transaction_get_data.php')
  data = JSON(json):dictionary()
  balance=data['meta']['balance']/100
  local transactions = {}
  for k,v in pairs(data['data']) do
    purpose=v['description']
    purpose=purpose:gsub("\\","\n")
    amount=v['amount']/100
    currency=v['amount_currency']
    date_str=v['date_fmttxt']
    local datePattern = "(%d%d)%.(%d%d)%.(%d%d%d%d)"
		local day, month, year = date_str:match(datePattern)
		local bookingDate = os.time({ day = day, month = month, year = year })
    local status=v['status']
    transaction = {
      bookingDate = bookingDate,
      purpose = purpose,
      amount = amount,
      currency = currency,
      booked = status == "Settled"
    }
    transactions[#transactions+1] = transaction
    if status ~= "Settled" then
      transaction2={
        bookingDate = bookingDate,
        purpose = 'Rückbuchung: '..purpose,
        amount = 0-amount,
        currency = currency,
        booked = false
      }
      transactions[#transactions+1] = transaction2
    end

  end

  return {balance=balance, transactions=transactions}
end
