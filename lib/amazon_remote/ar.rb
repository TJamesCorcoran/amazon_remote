require 'csv'
require 'selenium-webdriver'
require 'capybara'


# usage:
#     AMAZONUSER='user@user.com'  ; export AMAZONUSER
#     AMAZONPWD='password'  ; export AMAZONPWD
#     rails console
#     ar.login
#     ar.add_author_copy_to_cart("J9PZXRHNSX7",3)
#     ar.add_author_copy_to_cart("JGVTR3YPT3T", 1)
#     ar.checkout_start
#     ar.add_address("James Madison", "39 Evergreen Ln", nil, "Arlington", "MA", "02474", "781 555 1212", nil)
#     ar.place_order
#     ar.get_last_order_id


#
# https://www.selenium.dev/selenium/docs/api/rb/Selenium/WebDriver/Chrome/Options.html
#
# Interesting code.  Registers a driver, but the code inside the block
# only gets run when you instantiate the driver later, and then actually inspect / use it
#    sel = Capybara::Session.new(:selenium)  # <--- nope, not yet
#    sel.driver                              # <--- yep, here
#
#
Capybara.register_driver :selenium do |app|
  options = Selenium::WebDriver::Chrome::Options.new

  # does not work   - options[:clear_local_storage] = false
  # does not work   - options[:clear_session_storage] = false
  dr =Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)

#  dr.options[:clear_local_storage] = false
#  dr.options[:clear_session_storage] = false
  
  dr 
end

class Capybara::Selenium::Driver < Capybara::Driver::Base
  def reset!
    # Use instance variable directly so we avoid starting the browser just to reset the session
    if @browser
      begin
        #@browser.manage.delete_all_cookies <= cookie deletion is commented out!
      rescue Selenium::WebDriver::Error::UnhandledError => e
        # delete_all_cookies fails when we've previously gone
        # to about:blank, so we rescue this error and do nothing
        # instead.
      end
      @browser.navigate.to('about:blank')
    end
  end
end

class Ar

  attr_accessor :sel
  
  LOGIN_COOKIE_NAME = ".amazon.com"
  LOGIN_URL         = "https://kdp.amazon.com/en_US/"
  LOGOUT_URL        = "https://www.amazon.com/account/logout"
  CART_URL          = "https://www.amazon.com/gp/cart/view.html"
  ORDERS_URL        = "https://www.amazon.com/gp/your-account/order-history"
  
  VERBOSE = true

  # trade
  # -------
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

  
  def empty_cart
    @sel.visit(CART_URL)

    while del = @sel.first("input[value='Delete']", minimum: 0)
      del.click
    end
    
    if @sel.first("h1", text: "Your Amazon Cart is empty.", minimum: 0, wait: 10)
      return { success: true }
    else
      return { success: false, error_msg: "Cart not empty" }
    end
    
  end

  def delete_addrs()
    @sel.visit("https://www.amazon.com/a/addresses")
    while button = @sel.first("a#ya-myab-address-delete-btn-1", minimum: 0)
      button.click
      sleep(1)
      confirm = @sel.find("input[aria-labelledby='deleteAddressModal-1-submit-btn-announce']")
      confirm.click
    end
  end
    
  def add_author_copy_to_cart(code, quant=1, country_code="US")
    @sel.visit("https://kdp.amazon.com/en_US/title-setup/paperback/#{code}/author-orders")

    if @sel.first("h1", text: "Sign in with your Amazon login", minimum: 0, wait: 1)
      ret = helper_checkout_signin()
      return { success: false, error_msg: "login required, but failed"} unless @sel.first("span", text: "Order author copies", minimum: 0, wait: 1)
    end


    shipping_to_amazon_hash = Hash.new("US")
    ["AU", "DE", "ES", "FR", "IT"].each { |x| shipping_to_amazon_hash[x] = x }
    shipping_to_amazon_hash["GB"] = "UK"
    
    amazon_country_code = shipping_to_amazon_hash[country_code]
      
    @sel.find("option[value='#{amazon_country_code}']").click
    
    @sel.find("#data-quantity").set(quant)

    # the select pull-down menu (above) is weird and JS heavy.  Click another
    # entry field to let the JS know that we're done making our
    # selection.
    #
    @sel.find("#data-quantity").click    
    @sel.find("#submit-author-order-request-announce").click

    sleep(5)
    if @sel.first("H1", text: "Shopping Cart", wait: 10, minimum: 0)
      return { success: true }
    else
      
      return { success: false, error_msg: "Didn't land at shopping cart page" }
    end
  end

  def add_public_copy_to_cart(code, quant=1, country_code="US")
    @sel.visit("https://amazon.com/dp/#{code}")

    # if @sel.first("h1", text: "Sign in with your Amazon login", minimum: 0, wait: 1)
    #   ret = helper_checkout_signin()
    #   return { success: false, error_msg: "login required, but failed"} unless @sel.first("span", text: "Order author copies", minimum: 0, wait: 1)
    # end

    if quant > 1
      # click to expose the quant choices
      #
      @sel.first("#a-autoid-7-announce").click()

      # click our choice
      #
      quant_id = quant - 1
      @sel.first("#quantity_#{quant_id}").click()
    end
    
    @sel.first("#add-to-cart-button").click()
    
#    if @sel.first("H1", text: "Added to Cart", wait: 10, minimum: 0)
      return { success: true }
#    else
      
#      return { success: false, error_msg: "Didn't land at shopping cart page" }
#    end
  end


  def helper_checkout_signin()
    puts "-- sign in" if VERBOSE
    @sel.fill_in('ap_password', with: @@config.password)
    @sel.find("#signInSubmit").click
    
    {success: true }
  end    


  # checkout step 1
  #
  def checkout_start()
    puts "-- start_checkout" if VERBOSE
    @sel.visit(CART_URL)
    # WORKED FOR AUTHOR COPIES
    #     @sel.click_on("Proceed to checkout")
    @sel.first("span", text: "Proceed to checkout").click()

    if @sel.first("H1", text: "Sign-In", wait: 3, minimum: 0)
      helper_checkout_signin
    end
    
    return { success: false, error_msg: "checkout page not found"} unless @sel.first("h1", text: "Checkout") 
    return {success: true }
  end    

  # checkout step 2
  #
  def add_address(full_name, addr_1, addr_2, city, state_code, zip, phone, country_code = "US")
    puts "-- add_address" if VERBOSE

    # sanity check inputs
    #
    return { success: false, error_msg: "state code bad #{state_code}"   } if country_code == "US" && state_code.size != 2
    return { success: false, error_msg: "country code bad" } if country_code.size != 2
    return { success: false, error_msg: "phone bad"        } if phone.nil?

    @sel.find("a#addressChangeLinkId").click

    # page 3.1
    #
#    return { success: false, error_msg: "wrong start page" } unless @sel.first("H3", text: "Choose a shipping address", wait: 10)


    @sel.find("a#add-new-address-popover-link", wait: 10).click()


    if country_code != "US"
      
      # click once to expand the pull-down and to select
      # click a second time to trigger the JS
      #
      sel.find("option[value='#{country_code}']").click
      # sel.find("a[data-value='{\"stringVal\":\"#{country_code}\"}']", minimum: 0, wait: 2).click
    end

    puts "full_name = #{full_name}"
    sleep(2)
    @sel.find("input#address-ui-widgets-enterAddressFullName").set(full_name)
    sleep(5)
    
    @sel.find("input#address-ui-widgets-enterAddressPhoneNumber").set(phone)
    @sel.find("input#address-ui-widgets-enterAddressLine1").set(addr_1)
    @sel.find("input#address-ui-widgets-enterAddressLine2").set(addr_2) if addr_2
    
    @sel.find("input#address-ui-widgets-enterAddressPostalCode").click
    @sel.find("input#address-ui-widgets-enterAddressPostalCode").set(zip)

    if "US" == country_code
      # set city
      #
      @sel.find("input#address-ui-widgets-enterAddressCity").set(city)

      # two step process to click state code
      #
      @sel.find("select#address-ui-widgets-enterAddressStateOrRegion-dropdown-nativeId option[value='#{state_code}']").click
      data ={"stringVal":"#{state_code}"}.to_json
      @sel.find("a[data-value='#{data}']").click
    elsif "AU" == country_code
      
      # two step process to set city
      #
      sleep(1)
      @sel.find("span#address-ui-widgets-enterAddressCity").click
      sleep(2)
      data ={"stringVal":"#{city}"}.to_json
      @sel.find("a[data-value='#{data}']", wait: 3).click

      # no need to set state; automatic
      #
    end

    
    @sel.find("span#address-ui-widgets-form-submit-button input").click()

    # this verification step doesn't always happen ?!?
    #
    if @sel.first("h1", text: "Verify your address", minimum: 0, wait:2)
      @sel.find("input[name='address-ui-widgets-saveOriginalOrSuggestedAddress']").click

      if ! @sel.find("li.displayAddressLI displayAddressFullName", text: fulln_ame, wait: 10)
        return { success: false, error_msg: "name not set"}
      end
    end

    sleep(2)

    # this verification step doesn't always happen (occurs on weird street addresses with "1/2" in number)
    #
    if @sel.first("h4", text: "Review your address", minimum: 0, wait:5)
      @sel.first("input[aria-labelledby='address-ui-widgets-form-submit-button-announce']").click
    else
      # nothing
    end

    sleep(3)
    
#    if @sel.first("h1", text: "Verify your address", minimum: 0, wait:5)
#      return { success: true }
#    end
    
    return { success: true }
  end


  
  def set_cc(cc)
    if @sel.first("H3", text: "Choose a payment method", minimum: 0, wait: 3).nil?
      # no need to add CC this time
      return { success: true }
    end

    # only works bc I have a single CC at Amazon; would need more work for other cases
    #
    puts "set_cc 0"
    @sel.find("div.a-radio").click

    # not always required - add logic here
    #
    puts "set_cc 1"
    if @sel.first("h4", text: "Verify your card", wait: 1, minimum: 0)
      @sel.find(".apx-add-credit-card-number input").set(cc)
      @sel.click_button("Verify card")
    end

    puts "set_cc 2"
    @sel.first("input[aria-labelledby='orderSummaryPrimaryActionBtn-announce']", wait:5).click
    puts "set_cc 3"


    return { success: true }
  end

    # checkout step 2
  #
  def place_order()
    puts "-- place_order" if VERBOSE

    # @sel.first("span", text: "Place your order", wait: 10).click
    sleep(2)
    button = @sel.first(:css, "input[name='placeYourOrder1']", wait: 10, minimum: 0)
    if ! button
      return { success: false, error_msg: "place order button not found" }
    end
    button.click
    return { success: true }
  end

  def get_last_order_id()
    @sel.visit(ORDERS_URL)
    return { success: false, error_msg: "can't find ALL orders page" } unless @sel.first("H1", text: "Your Orders", wait: 10, minimum: 0)
    order_id = @sel.first("span.a-color-secondary bdi").text


    @sel.first("a", text: "View order details").click
    return { success: false, error_msg: "can't find SPECIFIC order page" } unless @sel.first("H1", text: "Order Details", wait: 5, minimum: 0)
    total_price = @sel.all("div#od-subtotals div.a-row div.a-span-last span").last.text
    total_price = total_price.gsub(/[^\d.]/, "").to_d

    return { success: true, order_id: order_id, total_price: total_price }
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
    
    @sel.fill_in('ap_email',    with: @@config.username)
    @sel.fill_in('ap_password', with: @@config.password)
    @sel.find('#signInSubmit').click

    unless @sel.first("h1", text: "Your Books", minimum: 0, wait: 5)
      return { success: false, error_msg: "Login failed" }
    end

    
    return yield if block_given?
  ensure
    logout if block_given?
  end

  # for development
  def get_session
    @sel
  end

  def set_session(sel)
    @sel = sel
  end

  def purge_addrs()
    @sel.visit("https://www.amazon.com/a/addresses")

    while del = @sel.first("a#ya-myab-address-delete-btn-1", minimum: 0)
      del.click
      sleep(1) # 2s ?
      @sel.first("input[aria-labelledby='deleteAddressModal-1-submit-btn-announce']").click
      puts "* deleted"
      # sleep(1)
    end
  end

end
