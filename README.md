= AmazonRemote

Amazon.com is a print publisher.

This Ruby / Rails library helps you interact with their website.

The API lets you:

* place orders

== Installation

1. add this to your Gemfile

    gem "amazon_remote", :git =>"http://github.com/TJamesCorcoran/amazon_remote"

2. at the command line type

    sudo apt-get install qt5-qmake
    bundle install


3. get a username and password from Amazon

4. Using credentials from previous step, add this to your config/application.rb

    AmazonRemote.configure do |config|
      config.username                      = 'tru<x>'   
      config.password                      = '<y>'
    end

5. That's it.  You can now begin interacting with the Amazon website programatically.
   Here's a sample program to get you started:

    B1_HARD  = "http://www.amazon.com/shop/travis-j-i-corcoran/book-1-hardcover/hardcover/product-23262551.html"
    B2_HARD  = "http://www.amazon.com/shop/travis-j-i-corcoran/book-2-hardcover/hardcover/product-23262547.html"

	def error_check(ret)
	  if ! ret[:success]
		puts "*** #{ret[:error_msg]}"
	  end
	end


    AmazonRemote.login do
      ret = AmazonRemote.empty_cart
      error_check(ret)
      
      ret = AmazonRemote.add_book_to_cart(B1_HARD)
      error_check(ret)

      ret = AmazonRemote.add_coupon("AMAZON15")
      error_check(ret)
      
      ret = AmazonRemote.start_checkout
      error_check(ret)

      ret = AmazonRemote.add_address("Random Eddie", "100 Quaker St", nil, "Weare", "NH", "02474", "603 529 3462", "US")
      error_check(ret)
      
      ret = AmazonRemote.choose_shipping_option
      error_check(ret)
      
      ret = AmazonRemote.billing("621")
      error_check(ret)
      
      ret = AmazonRemote.review
      error_check(ret)

      puts "order = #{ret[:order_num]} ; price = #{ ret[:total_price].to_currency}"

      
    end

== Development

To develop this library

  cd <location>
  rails new <fake_app_name>
  cd <fake_app_name>
  edit Gemfile to contain
  	   gem "amazon_remote",                         :path => "/home/tjic/personal/writing/ari/src/amazon_remote/Gemfile"
  rails console  	   
  AmazonRemote.login


== Use: Place Orders

    # 
    #
    AmazonRemote.get_amazon_release_dates(["JAN152628", "JAN152627"] )
    => {"JAN152628"=>Wed, 04 Mar 2015, 
       "JAN152627"=>Wed, 04 Mar 2015} 

       
