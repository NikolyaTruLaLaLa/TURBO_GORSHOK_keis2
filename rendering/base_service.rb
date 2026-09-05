class BaseService
    @client

    def check_conditions(operation, request_method) # предпроверки
    end

    def create_request(operation, ...) # создание выплаты/депозита
    end

    def process_callback(payload) # обработка webhook
    end

    def fetch_status(operation) # статус-запрос
    end
end