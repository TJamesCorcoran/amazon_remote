require 'csv'
require 'selenium-webdriver'
require 'capybara'


# usage:
#     AMAZONUSER='user@user.com'  ; export AMAZONUSER
#     AMAZONPWD='password'  ; export AMAZONPWD
#     rails console
#     ar.login
#     ar.add_book_to_cart("J9PZXRHNSX7",3)
#     ar.add_book_to_cart("JGVTR3YPT3T", 1)
#     ar.checkout_start
#     ar.add_address("James Madison", "39 Evergreen Ln", nil, "Arlington", "MA", "02474", "781 555 1212", nil)
#     ar.place_order
#     ar.get_last_order_id


Capybara.register_driver :selenium do |app|
   options = Selenium::WebDriver::Chrome::Options.new
   Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end


class Ar
  
  LOGIN_COOKIE_NAME = ".amazon.com"
  LOGIN_URL         = "https://kdp.amazon.com/en_US/"
  LOGOUT_URL        = "https://www.amazon.com/account/logout"
  CART_URL          = "https://www.amazon.com/gp/cart/view.html"
  ORDERS_URL        = "https://www.amazon.com/gp/your-account/order-history"
  
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
    
  def add_book_to_cart(code, quant=1)
    @sel.visit("https://kdp.amazon.com/en_US/title-setup/paperback/#{code}/author-orders")



    if @sel.first("h1", text: "Sign in with your Amazon login", minimum: 0, wait: 1)
      ret = helper_checkout_signin()
      return { success: false, error_msg: "login required, but failed"} unless @sel.first("span", text: "Order author copies", minimum: 0, wait: 1)
    end

    
    @sel.find("#data-quantity").set(quant)

    @sel.find("option[value='US']").click

    # the select pull-down menu (above) is weird and JS heavy.  Click another
    # entry field to let the JS know that we're done making our
    # selection.
    #
    @sel.find("#data-quantity").click    

    @sel.find("#submit-author-order-request-announce").click

    if @sel.first("H1", text: "Shopping Cart", wait: 10)
      return { success: true }
    else
      return { success: false, error_msg: "Didn't land at shopping cart page" }
    end
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
    @sel.click_on("Proceed to checkout")

    if @sel.first("H1", text: "Sign-In", wait: 3, minimum: 0)
      helper_checkout_signin
    end
    
    return { success: false, error_msg: "checkout page not found"} unless @sel.first("h1", text: "Checkout") 
    return {success: true }
  end    

  # checkout step 2
  #
  def add_address(full_name, addr_1, addr_2, city, state_code, zip, phone, country_code = nil)
    puts "-- add_address" if VERBOSE

    # sanity check inputs
    #
    return { success: false, error_msg: "state code bad"   } if state_code.size != 2
    raise "country_code not supported" if country_code
#    return { success: false, error_msg: "country code bad" } if country_code.size != 2
    return { success: false, error_msg: "phone bad"        } if phone.nil?

    @sel.find("a#addressChangeLinkId").click

    # page 3.1
    #
    return { success: false, error_msg: "wrong start page" } unless @sel.first("H3", text: "Choose a shipping address", wait: 10)

    @sel.find("a#add-new-address-popover-link").click()

    @sel.find("input#address-ui-widgets-enterAddressFullName").set(full_name)
    @sel.find("input#address-ui-widgets-enterAddressPhoneNumber").set(phone)
    @sel.find("input#address-ui-widgets-enterAddressLine1").set(addr_1)
    @sel.find("input#address-ui-widgets-enterAddressLine2").set(addr_2) if addr_2
    @sel.find("input#address-ui-widgets-enterAddressCity").set(city)

    # two step process to click state code
    @sel.find("select#address-ui-widgets-enterAddressStateOrRegion-dropdown-nativeId option[value='#{state_code}']").click
    data ={"stringVal":"#{state_code}"}.to_json
    @sel.find("a[data-value='#{data}']").click
    
    @sel.find("input#address-ui-widgets-enterAddressPostalCode").click
    @sel.find("input#address-ui-widgets-enterAddressPostalCode").set(zip)

    @sel.find("span#address-ui-widgets-form-submit-button input").click()

    if @sel.first("h1", text: "Verify your address", minimum: 0, wait:2)
      @sel.find("input[name='address-ui-widgets-saveOriginalOrSuggestedAddress']").click
    end

    if ! @sel.find("li.displayAddressLI displayAddressFullName", text: full_name, wait: 10)
      return { success: false, error_msg: "name not set"}
    end

    return { success: true }
  end


  

  def set_cc(cc)
    return { success: false, error_msg: "not CC page" } unless @sel.first("H3", text: "Choose a payment method")    

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

    # checkout step 2
  #
  def place_order()
    @sel.first("span", text: "Place your order").click    
  end

  def get_last_order_id()
    @sel.visit(ORDERS_URL)
    return { success: false, error_msg: "can't find order page" } unless @sel.first("H1", text: "Your Orders", wait: 10)
    @sel.first("span.a-color-secondary bdi").text
    # https://www.amazon.com/gp/your-account/order-details/ref=ppx_yo_dt_b_order_details_o00?ie=UTF8&orderID=114-1631688-5799437
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
  

end
