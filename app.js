import express from 'express'


const app = express()


app.get('/api/hello', (req, res) => {
res.json({ message: 'hello' })
})


app.get('/health', (req, res) => {
res.json({ status: 'UP' })
})


export default app