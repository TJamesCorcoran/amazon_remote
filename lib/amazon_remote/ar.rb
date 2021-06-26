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
  ORDER_URL         = "https://www.amazon.com/gp/your-account/order-details/ref=ppx_yo_dt_b_order_details_o00?ie=UTF8&orderID="
  CANCELLED_URL = "https://www.amazon.com/gp/your-account/order-history/ref=ppx_yo_dt_b_cancelled_orders?ie=UTF8&orderFilter=cancelled"
  
  VERBOSE = true

  CC_STR = "4003 4492 6495 3926"
  
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

  # def login_again_if_required()
  #   if @sel.first("h1", text: "Sign in with your Amazon login", minimum: 0, wait: ) ||
  #      @sel.first("span", text: "Sign in to your account", minimum: 0, wait:2) ||
  #      @sel.first("h1", text: "Sign-In", minimum: 0, wait:2) ||
  #     ret = helper_checkout_signin()
      
  #     return { success: false, error_msg: "login required, but failed"} unless @sel.first("span", text: "Order author copies", minimum: 0, wait: 1)
  #   end

  # end
  
  def add_author_copy_to_cart(code, quant=1, shipping_country_code)
    @sel.visit("https://kdp.amazon.com/en_US/title-setup/paperback/#{code}/author-orders")

    puts "here-1"
    if @sel.first("h1", text: "Sign in with your Amazon login", minimum: 0, wait: 1) ||
       @sel.first("span", text: "Sign in to your account", minimum: 0, wait:1)
          puts "here-2"
      ret = helper_checkout_signin()
      
      return { success: false, error_msg: "login required, but failed"} unless @sel.first("span", text: "Order author copies", minimum: 0, wait: 1)
    end

    puts "here-3"
      
    @sel.find("option[value='#{shipping_country_code}']").click
    
    @sel.find("#data-quantity").set(quant)

    # the select pull-down menu (above) is weird and JS heavy.  Click another
    # entry field to let the JS know that we're done making our
    # selection.
    #
    @sel.find("#data-quantity").click    
    @sel.find("#submit-author-order-request-announce").click

    if @sel.first("span", text: "Sign in to your account", minimum: 0, wait:10)
      puts "here-4"
      ret = helper_checkout_signin()
      
      return { success: false, error_msg: "login required, but failed"} unless @sel.first("span", text: "Order author copies", minimum: 0, wait: 1)
      puts "here-5"
    end
    puts "here-6"
    
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
  def checkout_start(amazon_code)
    puts "-- start_checkout #{amazon_code}" if VERBOSE

    if "US" == amazon_code 
      @sel.visit(CART_URL)
      # WORKED FOR AUTHOR COPIES
      #     @sel.click_on("Proceed to checkout")
      @sel.first("span", text: "Proceed to checkout").click()
      return { success: false, error_msg: "checkout page not found"} unless @sel.first("h1", text: "Checkout", wait: 3) 
      return {success: true }

    elsif "AU" == amazon_code
      # .au
      @sel.first("input[value='Proceed to checkout']").click()
      
      if @sel.first("H1", text: "Sign-In", wait: 3, minimum: 0)
        helper_checkout_signin
      end
      
      return { success: false, error_msg: "checkout page not found"} unless @sel.first("h1", text: "Checkout") 
      return {success: true }
    else
      raise "unsupported #{amazon_code}"
    end
  end    

  # checkout step 2
  #
  def add_address(amazon_code, full_name, addr_1, addr_2, city, state_code, zip, phone, country_code = "US")
    puts "-- add_address" if VERBOSE

    # sanity check inputs
    #
    return { success: false, error_msg: "state code bad #{state_code}"   } if country_code == "US" && state_code.size != 2
    return { success: false, error_msg: "country code bad" } if country_code.size != 2
    return { success: false, error_msg: "phone bad"        } if phone.nil?

    if "US" == amazon_code

      # get form for new addr
      #
      @sel.find("a#addressChangeLinkId").click
      @sel.find("a#add-new-address-popover-link", wait: 10).click()


      # set country code
      #
      if country_code != "US"
        
        # click once to expand the pull-down and to select
        # click a second time to trigger the JS
        #
        sel.first("option[value='#{country_code}']").click
        sleep(1)
      end

      # name, addr1, addr2, phone, postal code
      #
      puts "full_name = #{full_name}"
      @sel.find("input#address-ui-widgets-enterAddressFullName").set(full_name)
      
      @sel.find("input#address-ui-widgets-enterAddressPhoneNumber").set(phone)
      @sel.find("input#address-ui-widgets-enterAddressLine1").set(addr_1)
      @sel.find("input#address-ui-widgets-enterAddressLine2").set(addr_2) if addr_2 && addr_2.size > 0
      
      @sel.find("input#address-ui-widgets-enterAddressPostalCode").click
      @sel.find("input#address-ui-widgets-enterAddressPostalCode").set(zip)

      # city and state code (interface varies by country chosen)
      #
      if "US" == country_code
        # set city
        #
        @sel.find("input#address-ui-widgets-enterAddressCity").set(city)

        # two step process to click state code
        #
        @sel.find("select#address-ui-widgets-enterAddressStateOrRegion-dropdown-nativeId option[value='#{state_code}']").click
        data ={"stringVal":"#{state_code}"}.to_json
        @sel.find("a[data-value='#{data}']").click
      elsif "CA" == country_code
        # set city
        #
        @sel.find("input#address-ui-widgets-enterAddressCity").set(city)

        # two step process to click state code
        #
        state_name = { "AB" => "Alberta",
          "BC" => "British Columbia",
          "MB" => "Manitoba",
          "NB" => "New Brunswick",
          "NL" => "Newfoundland",
          "NT" => "Northwest Territories",
          "NS" => "Nova Scotia",
          "NU" => "Nunavut",
          "ON" => "Ontario",
          "PE" => "Prince Edward Island",
          "QC" => "Quebec",
          "SK" => "Saskatchewan",
          "YT" => "Yukon"}[state_code]

        @sel.find("select#address-ui-widgets-enterAddressStateOrRegion-dropdown-nativeId option[value='#{state_name}']").click
        data ={"stringVal":"#{state_name}"}.to_json
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

      elsif "MX" == country_code
        @sel.find("input[name='address-ui-widgets-enterAddressPostalCode-submit']").click()
        sleep(1)
      elsif "SG" == country_code
        # no city or state
      elsif "SE" == country_code
        @sel.find("input#address-ui-widgets-enterAddressCity").set(city)
      elsif  "AT" == country_code
        @sel.find("input#address-ui-widgets-enterAddressCity").set(city)
        @sel.find("input#address-ui-widgets-enterAddressStateOrRegion").set("  ")  # <--- what's the right solution here?
        sleep(5)
      else
        @sel.find("input#address-ui-widgets-enterAddressCity").set(city)
        @sel.find("input#address-ui-widgets-enterAddressStateOrRegion").set(state_code)
      end


      
      # days of the week
      #
      choose_days = @sel.first("span#address-ui-widgets-addr-details-business-hours", minimum: 0)
      if choose_days
        choose_days.click()
        data ={"stringVal":"NONE"}.to_json
        weekdays_only = @sel.first("a[data-value='#{data}']", minimum: 0)
        if weekdays_only
          weekdays_only.click()
        end
      end
      
      @sel.find("span#address-ui-widgets-form-submit-button input").click()

      sleep(2)

      # this verification step doesn't always happen (occurs on weird street addresses with "1/2" in number)
      #
      if use_suggested = @sel.first("input[name='address-ui-widgets-saveOriginalOrSuggestedAddress']", wait: 1, minimum: 0)
        use_suggested.click
        sleep(2)
      end

      sleep(6)
      
    end
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

    sleep(2)

    return { success: true }
  end

    # checkout step 2
  #
  def place_order()
    puts "-- place_order" if VERBOSE

    sleep(3)
    button = @sel.first(:css, "input[name='placeYourOrder1']", wait: 20, minimum: 0)
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

  # assumes we're already at the single order page
  #
  def update_info_one
    if sel.first("h1", text: "Sign-In", minimum: 0, wait:2)
      ret = helper_checkout_signin()
    end
    
    radio = sel.first("div.a-radio input", minimum: 0 )
    if ! radio
      puts "skipping: #{order_id} - no button"
      return
    end

    radio.click()
    if (input = sel.first("div.apx-add-credit-card-number input", minimum: 0, wait: 5))
      input.set(CC_STR)
      sel.click_button("Verify card")
      sleep(1)
    end
    sel.first("input[name='ppw-widgetEvent:SetPaymentPlanSelectContinueEvent']").click()
    #    sel.click_button("Continue")
    sleep(2)
    if sel.first("h4", text: "Payment information has been updated", minimum: 0, wait: 10)
      puts("done: ") # would be nice to print order_id here
    else
      puts("**** ERROR  #{order_id}")
    end

  end
  
  # for specific orders that have failing charges
  #
  def update_info_list

    [
      "111-2784570-9745051",
      "111-8978261-2265040",
      "114-8046766-5028252",
      "114-5957974-3294605",
      "114-7888738-1405805",
      "114-8046766-5028252",
      "111-4143475-8597836",
      "114-7888738-1405805",
      "114-4168802-9533046",
      
    ].uniq.each do |order_id|

      sel.visit(ORDER_URL + order_id)
      sel.find("#a-autoid-7-announce").click

      if sel.first("h1", text: "Sign-In", minimum: 0, wait:2)
        ret = helper_checkout_signin()
      end

      # REPLACE EVERYTHING FROM HERE >>>
      #
      radio = sel.first("div.a-radio input", minimum: 0 )
      if ! radio
        puts "skipping: #{order_id} - no button"
        next
      end

      radio.click()
      if (input = sel.first("div.apx-add-credit-card-number input", minimum: 0, wait: 5))
        input.set(CC_STR)
        sel.click_button("Verify card")
        sleep(1)
      end
      sel.first("input[name='ppw-widgetEvent:SetPaymentPlanSelectContinueEvent']").click()
      #    sel.click_button("Continue")
      sleep(2)
      if sel.first("h4", text: "Payment information has been updated", minimum: 0, wait: 10)
        puts("done: #{order_id}")
      else
        puts("**** ERROR  #{order_id}")
      end
      #
      # <<< TO HERE
      #
      # with a call to update_info_one()
    end
  end

  # for every unshipped order
  # 
  def update_info_all
    sel.visit(ORDERS_URL)
    sel.visit("https://www.amazon.com/gp/your-account/order-history/ref=ppx_yo_dt_b_pagination_87_88?ie=UTF8&orderFilter=months-3&search=&startIndex=870")
    ii = 0
    begin
      ii += 1
      puts "=== page #{ii}"

      # login if needed
      #
      if sel.first("h1", text: "Sign-In", minimum: 0, wait:2)
        ret = helper_checkout_signin()
      end

      # does this pagination page have any bad orders?
      #
      if sel.first("h4.a-alert-heading", minimum: 0, wait: 1)
        pagination_url = URI.parse(sel.current_url)
        while revise_button = sel.first("a", text:"Revise Payment Method", minimum: 0, wait: 1)
          puts "   >>> one"
          revise_button.click()
          update_info_one()
          sel.visit(pagination_url)
        end
      end
      next_link = sel.first("li.a-last a", minimum: 0, wait: 5)
      next_link.click() if next_link
    end while next_link && ii < 200
    
      
  end

  def find_cancelled()
    sel.visit(CANCELLED_URL)
    ii = 0
    begin
      ii += 1
      puts "=== page #{ii}"

      # login if needed
      #
      if sel.first("h1", text: "Sign-In", minimum: 0, wait:2)
        ret = helper_checkout_signin()
      end

      # does this pagination page have any bad orders?
      #
      sel.all("bdi", minimum: 0, wait: 1).each do |bdi|
        puts " * #{bdi.text}"
      end
      next_link = sel.first("li.a-last a", minimum: 0, wait: 5)
      next_link.click() if next_link
    end while next_link && ii < 200

  end
    
  
  def replace_cancelled
    # full order cancelled
    [
      "114-9544000-2244233",
      "112-9574325-5502639",
      "112-2264931-7828267",
      "113-0704810-7938666",
      "111-5003743-1847463",
      "113-7804336-2718637",
      "112-2290357-8088223",
      "111-6272285-2773839",
      "114-1135338-1781021",
      "114-9947165-2851432",
      "112-8036067-3563419",
      "111-6378596-5782641",
      "111-8584428-6130663",
      "114-9141385-1865018",
      "113-7882628-4851459",
      "111-7335909-9298660",
      "113-4490429-8517024",
      "113-0661674-9251420",
      "111-6767643-0689068",
      "111-7135354-3434632",
      "111-7379964-0021838",
      "112-1847004-8859459",
      "111-6620854-2174636",
      "111-2682191-1266636",
      "111-9708121-3282642",
      "113-5139975-7273824",
      "114-0638629-1221016",
      "113-6764800-1488257",
      "113-6831438-7290660",
      "113-1470191-2295401",
      "111-8332148-0351457",
      "113-4022576-7430666",
      "111-3514193-8593844",
      "111-6431468-4859415",
      "111-5852025-1329039",
      "114-1873074-8313005",
      "114-9659962-0795433",
      "113-4833267-5493845",
      "114-7248082-3713017",
      "114-3714724-9124250",
      "111-5362460-2418645",
      
    ]

    # item cancelled
    [
      "112-7152627-1025826",
      "111-5823412-2005868",
      "113-7377023-7657823",

      "112-9245342-4980235",
      "112-1484911-5977006",
      "111-4747702-3705011",
      "113-7098012-8006615",
      "113-4851195-8216252",
      "111-8526837-9165000",
      "111-0378521-1225012",
      "112-5327533-4734659",
      "111-5013419-5539421",
      "111-2634666-0388243",
      "111-2369844-1961062",
      "113-0375133-8526639",
      "113-8363268-7046652",
      "114-9960346-2957043",
      "111-2118553-5588207",
      "113-1967534-9308241",
      "112-8438655-6505804",
      "114-0297750-3253800",
      "113-3159750-2296227",
      "112-9338113-2205016",
      
    ]

    # refund
    [
      "112-7617803-2354616",
    ]

    # returned
    [
      "114-6873865-1472260",
      "112-7617803-2354616",
    ]
  end
  
end
