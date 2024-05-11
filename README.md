BasicUrl
========

A simple Ruby module that provides basic URL operations.

This implementation supports:

- Object oriented operations (`obj.join(component)` instead of `MODULE.join(obj, component)`)
- Easy URL encoding
- Joining relative paths (`obj('a/b').join('c')` returns `a/b/c` not `a/c`)

This gem *does not try to be RFC compliant when joining URLs.*

Given that the majority of other implementations all do some degree of shenanigans when joining URLs it's assumed that `a/b/c` + `d` = `a/d` is buried in a spec somewhere.
This library does not do that, it does `a/b/c` + `d` = `a/b/c/d`, which is what is needed in 99% of cases.
If you need full RFC compliance this gem is not suitable.


## Usage

```ruby
require 'BasicURL'

base_url = BasicUrl.parse('192.0.2.64/api/v1', default_protocol: 'https')

puts(base_url.path)
# api/v1

# Basic joining, returns a new object
# join! is also available to update the current object
controller = base_url.join('some/controller')
puts controller.path
# api/v1/some/controller

# By default absolute paths replace
controller = base_url.join('/some/controller')
puts controller.path
# some/controller

# But this is selectable
controller = base_url.join('/some/controller', replace_when_absolute: false)
puts controller.path
# api/v1/some/controller             

# To get a URL string call .to_s
puts controller.to_s
# https://192.0.2.64/api/v1/some/controller

# Path components are URL encoded by default
puts BasicUrl.new(protocol: 'http', host: 'foo.local', path: '/api/v0/some path/with spaces', params: { key: 'value:1', key2: 'Value!', key3: ['and', 'arrays']}).to_s
# http://foo.local/api/v0/some+path/with+spaces?key=value%3A1&key2=Value%21&key3[]=and&key3[]=arrays

# Query parameters can also be added with params=.  This modifies the object
controller = base_url.join('some/controller')

controller.params = { key1: 'val1' }
controller.params[:key2] = 'val2'
puts controller.to_s
# https://192.0.2.64/api/v1/some/controller?key1=val1&key2=val2
```


## Contributing

TODO

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/basic_url.
