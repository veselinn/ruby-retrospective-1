require 'bigdecimal'
require 'bigdecimal/util'

class Promotion
  def Promotion.create(hash)
    type, attrs = hash.flatten
    
    case type
      when :get_one_free then GetOneFreePromotion.new(attrs)
      when :package then PackagePromotion.new(attrs)
      when :threshold then ThresholdPromotion.new(attrs)
      else NoPromotion.new
    end
  end
end

class GetOneFreePromotion
  def initialize(free_item_frequency)
    @free_item_frequency = free_item_frequency
  end
  
  def calculate_discount(number_of_items, item_price)
    (number_of_items / @free_item_frequency) * item_price
  end
  
  def to_s_representation
    "buy #{@free_item_frequency - 1}, get 1 free"
  end
end

class PackagePromotion
  def initialize(promotion_attrs)
    @package_size, discount_percent = promotion_attrs.flatten
	  @discount_percent = discount_percent / '100'.to_d
  end
  
  def calculate_discount(number_of_items, item_price)
    (number_of_items - number_of_items % @package_size) *
      @discount_percent * item_price
  end
  
  def to_s_representation
    "get #{(@discount_percent * 100).to_i}% off for every #{@package_size}"
  end
end

class ThresholdPromotion
  def initialize(promotion_attrs)
    @threshold, discount_percent = promotion_attrs.flatten
    @discount_percent = discount_percent / '100'.to_d
  end
  
  def calculate_discount(number_of_items, item_price)
    if number_of_items > @threshold
      (number_of_items - @threshold)  * item_price * @discount_percent
    else
      '0'.to_d
    end
  end
  
  def to_s_representation
    ordinalized_threshold = Utils::Conversions.ordinalize(@threshold)
    discount_percent = (@discount_percent * 100).to_i
    "#{discount_percent}% off of every after the #{ordinalized_threshold}"
  end
end

class NoPromotion
  def calculate_discount(number_of_items, item_price)
    '0'.to_d
  end
  
  def to_s_repsentation
    ''
  end
end
  
class Coupon
  def Coupon.create(name, coupon_data)
    type, attrs = coupon_data.flatten
    
    case type
      when :percent then PercentCoupon.new(name, attrs)
      when :amount then FlatAmountCoupon.new(name, attrs)
      else NoCoupon.new
    end
  end
end

class PercentCoupon
  attr_reader :name

  def initialize(name, discount_percent)
    @name = name
    @discount_percent = discount_percent / '100'.to_d
  end
  
  def calculate_discount(total)        
    total * @discount_percent
  end
  
  def to_s_representation
    "Coupon #{@name} - #{(@discount_percent * 100).to_i}% off"
  end
end

class FlatAmountCoupon
  attr_reader :name

  def initialize(name, discount_amount)
    @name = name
    @discount_amount = BigDecimal(discount_amount.to_s)
  end
  
  def calculate_discount(total)
    [total, @discount_amount].min
  end
  
  def to_s_representation
    format("Coupon %s - %.2f off", @name, @discount_amount.to_f)
  end
end

class NoCoupon
  attr_reader :name

  def initialize
    @name = ''
  end
  
  def calculate_discount(total)
    '0'.to_d
  end
  
  def to_s_representation
    ''
  end
end
  
class Product
  attr_reader :name, :price, :promotion
  
  def initialize (name, price, promotion)
    @name, @price, @promotion = name, price, Promotion.create(promotion)
  end
end

class LineItem
  attr_reader :count

  def initialize(product, count = 0)
    if (count > 99 || count < 0)
      raise "Invalid parameters passed."
    end
    @product, @count = product, count
  end
  
  def increase(count)
    if (@count + count > 99 && count <= 0)
      raise "Invalid parameters passed."
    else 
      @count += count
    end
  end
  
  def name
    @product.name
  end
  
  def price
    price_without_discount - discount
  end
  
  def price_without_discount
    @product.price * @count
  end
  
  def discount
    @product.promotion.calculate_discount(@count, @product.price)
  end
  
  def discount_representation
    @product.promotion.to_s_representation
  end
  
  def discounted?
    !@product.promotion.kind_of? NoPromotion
  end
end

class Inventory  
  def initialize
    @products = []
    @coupons = []
  end
  
  def register(name, price, promotion = {})
    if (name.length > 40 || 0.01 > price.to_f || price.to_f > 999.99 ||
        @products.detect { |product| product.name == name })
      raise "Invalid parameters passed."
    end
    @products << Product.new(name, price.to_d, promotion)
  end
  
  def register_coupon(name, coupon_data)
    if (@coupons.detect { |coupon| coupon.name == name })
      raise "A coupon with the same name already exists."
    end
    @coupons << Coupon.create(name, coupon_data)
  end
  
  def get_item(name)
    @products.detect { |product| product.name == name } or 
      raise 'Unexisting product'
  end
  
  def get_coupon(name)
    @coupons.detect { |coupon| coupon.name == name } or 
      raise 'Unexisitng coupon'
  end
  
  def new_cart
    Cart.new(self)
  end
end

class Cart
  attr_reader :items, :coupon

  def initialize(inventory)
    @inventory = inventory
    @items = []
    @coupon = NoCoupon.new
  end
  
  def add(item_name, amount = 1)
    item = @items.detect { |item| item.name == item_name }
    if (item)
      item.increase(amount)
    else
      @items << LineItem.new(@inventory.get_item(item_name), amount)
    end
  end
  
  def use(coupon_name)
    @coupon = @inventory.get_coupon(coupon_name)
  end
  
  def total    
    items_price - @coupon.calculate_discount(items_price)
  end
  
  def coupon_discount
    @coupon.calculate_discount(items_price)
  end
  
  def invoice
    InvoiceCreator.create_invoice(self)
  end
  
  private
  
  def items_price
    @items.map(&:price).inject(&:+)
  end
end

class InvoiceCreator
  DelimiterLine = "+#{"-" * 48}+#{"-" * 10}+\n"
  
  def InvoiceCreator.create_invoice(cart)
    invoice = InvoiceCreator.create_header
    cart.items.each do |item|
      invoice << InvoiceCreator.create_product_entry(item)
    end
    invoice << InvoiceCreator.create_coupon_entry(cart)
    invoice << InvoiceCreator.create_footer(cart.total)
  end
  
  private
  
  def InvoiceCreator.create_header
    DelimiterLine + format("| %s %s | %s |\n", "Name".ljust(42), "qty", 
      "price".rjust(8)) + DelimiterLine
  end

  def InvoiceCreator.create_footer(total)
    DelimiterLine + format("| %s | %8.2f |\n", "TOTAL".ljust(46), total.to_f) +
      DelimiterLine
  end
  
  def InvoiceCreator.create_coupon_entry(cart)
    if (cart.coupon.kind_of? NoCoupon)
      ''
    else
      format("| %s | %8.2f |\n", 
        cart.coupon.to_s_representation.ljust(46), 
        -cart.coupon_discount.to_f)
    end
  end
  
  def InvoiceCreator.create_product_entry(item)
    product_entry = ''
    product_entry << format("| %s %3d | %8.2f |\n", item.name.ljust(42), 
      item.count , item.price_without_discount.to_f)
    if (item.discounted?)
      product_entry << format("|   %s | %8.2f |\n", 
        "(#{item.discount_representation})".ljust(44), -item.discount.to_f)
    end
    
    product_entry
  end
end

#I wish I could have used the active_support's ordinalize.
module Utils
  class Conversions
    def Conversions.ordinalize(number)
      if (11..13).cover?(number % 100)
        return "#{number}th"
      else
	      Conversions.ordinalize_digit(number)
      end	
    end
    
    private
       
    def Conversions.ordinalize_digit(number)
      case number % 10
          when 1 then return "#{number}st"
	        when 2 then return "#{number}nd"
	        when 3 then return "#{number}rd"
	        else return "#{number}th"
	      end
    end
  end
end