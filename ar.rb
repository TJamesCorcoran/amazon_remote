require 'csv'
require 'selenium-webdriver'
require 'capybara'

Capybara.register_driver :selenium do |app|
  
   options = Selenium::WebDriver::Chrome::Options.new
#   options.add_preference('browser.download.dir', DownloadHelpers::PATH.to_s)
#  options.add_preference('browser.download.folderList', 2)
#   options.add_preference('browser.helperApps.neverAsk.saveToDisk', "text/csv")

   Capybara::Selenium::Driver.new(app, :browser => :chrome, :options => options)

end


class AmazonRemote


  
  # def get_agent()    @@agent   end
  # def get_cookies()    @@agent.cookie_jar.jar.first[1].first[1].keys   end
  #  @@agent = Mechanize.new
  #  @@agent.user_agent = "Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.9.2.13) Gecko/20101206 Ubuntu/10.04 (lucid) Firefox/3.6.13"
  #  @@agent.post_connect_hooks << MechanizeCleanupHook.new

  LOGIN_COOKIE_NAME = ".amazon.com"
  LOGIN_URL         = "https://kdp.amazon.com/en_US/"
  LOGOUT_URL        = "https://www.amazon.com/account/logout"
  CART_URL          = "https://www.amazon.com/gp/cart/view.html"

  VERBOSE = true

  # ETC 1           - J2KGTA4W6FK
  # ETC 2           - J1QMPCAQFKV
  # The Team        - J9PZXRHNSX7
  # Staking a Claim - JGVTR3YPT3T
  # Ari 1           - YRKMTRMSTCY
  # Ari 2           - MCNSNEERB6K
  # 

  def initialize()
    @sel = Capybara::Session.new(:selenium)
  end
  
  def add_book_to_cart(code, quant=1)
    @sel.visit("https://kdp.amazon.com/en_US/title-setup/paperback/#{code}/author-orders")
    @sel.find("#data-quantity").set(quant)

    @sel.find("option[value='US']").click

    # the select pull-down menu (above) is weird and JS heavy.  Click another
    # entry field to let the JS know that we're done making our
    # selection.
    #
    @sel.find("#data-quantity").click    

    @sel.find("#submit-author-order-request-announce").click
    
    { :success => true }
  end


  #--------------------
  # checkout process
  #--------------------  

  def empty_cart
    raise "unimplemented"
  end
  
  # checkout step 1
  #
  def checkout_start()
    puts "-- start_checkout" if VERBOSE
    @sel.visit(CART_URL)
    @sel.click_on("Proceed to checkout")

    {:success => true }
  end    

  # checkout step 2
  #
  def checkout_signin()
    puts "-- start_checkout" if VERBOSE
    @sel.fill_in('ap_password', :with => config.password)
    @sel.find("#signInSubmit").click
    
    {:success => true }
  end    

  
  # checkout step 3
  #
  def add_address(full_name, addr_1, addr_2, city, state_code, zip, phone, country_code)
    puts "-- add_address" if VERBOSE

    # sanity check inputs
    #
    return { :success => false, :error_msg => "state code bad"   } if state_code.size != 2
    return { :success => false, :error_msg => "country code bad" } if country_code.size != 2
    return { :success => false, :error_msg => "phone bad"        } if phone.nil?

    @sel.find("a#addressChangeLinkId").click

    # page 3.1
    # 
    return { :success => false, :error_msg => "wrong start page" } unless @sel.first("H3", :text=>"Choose a shipping address")

    @sel.find("a#add-new-address-popover-link").click()

    @sel.find("input#address-ui-widgets-enterAddressFullName").set(full_name)
    @sel.find("input#address-ui-widgets-enterAddressPhoneNumber").set(phone)
    @sel.find("input#address-ui-widgets-enterAddressLine1").set(addr_1)
    @sel.find("input#address-ui-widgets-enterAddressLine2").set(addr_2) if addr_2
    @sel.find("input#address-ui-widgets-enterAddressCity").set(city)

    # two step process to click state code
    @sel.find("option[value='#{state_code}']").click
    data ={"stringVal":"#{state_code}"}.to_json
    @sel.find("a[data-value='#{data}']").click
    
    @sel.find("input#address-ui-widgets-enterAddressPostalCode").click
    @sel.find("input#address-ui-widgets-enterAddressPostalCode").set(zip)

    @sel.find("span#address-ui-widgets-form-submit-button input").click()

    if @sel.first("h1", text: "Verify your address")
      @sel.find("input[name='address-ui-widgets-saveOriginalOrSuggestedAddress']").click
    end

    
    sleep(7)
    return { :success => false, :error_msg => "error in address" , :body => @sel.body}  if @sel.first("div.feedback.error", :text => "We couldn't validate")
    return { :success => false, :error_msg => "address not set" , :body => @sel.body}  if ! @sel.first("div.name", :text => full_name)
    return { :success => true }
  end

  def set_cc(cc)
    return { :success => false, :error_msg => "not CC page" } unless @sel.first("H3", :text=>"Choose a payment method")    

    # only works bc I have a single CC at Amazon; would need more work for other cases
    # 
    @sel.find("div.a-radio").click

    # not always required - add logic here
    #
    if false
      @sel.find(".apx-add-credit-card-number input").set(cc)
      @sel.click_button("Verify card")
    end

    @sel.click_button("Use this payment method")    
  end

  def place_order()
    sel.first("span", text: "Place your order").click    
  end


  #--------------------
  # login / logout
  #--------------------  
  def logout
    puts "-- logout" if VERBOSE
    @sel.visit(LOGOUT_URL)
  end

  def login
    verbose = true

    @sel = Capybara::Session.new(:selenium)    # selenium supports javascript
    @sel.visit(LOGIN_URL)

    @sel.find("span#signinButton span.a-button-inner a").click
    
    @sel.fill_in('ap_email', :with => config.username)
    @sel.fill_in('ap_password', :with => config.password)
    @sel.find('#signInSubmit').click
    
    return yield if block_given?
  ensure
    logout if block_given?
  end

  # for development
  def get_session
    @sel
  end
  

end
