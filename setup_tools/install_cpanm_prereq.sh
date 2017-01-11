for module in 'Config::Tiny' 'Config::Any' 'Log::Handler' \
    'Expect' 'Date::Format' 'XML::LibXML' 'JSON' 'DBI' \
    'Net::SNMP' 'Digest::MD5'
do
    cpanm --notest $module
done
