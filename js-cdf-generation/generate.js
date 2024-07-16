import * as fs from 'fs'
import { toBn } from 'evm-bn';
import { formatEther } from 'ethers/utils';
import { AbiCoder } from 'ethers/abi';
import gaussian from 'gaussian';

const LOOP_SIZE = 100000; //if changed here, should be changed in src/test/DifferentialTestCDF.t.sol

const parse = (x) => toBn(x.toString())._hex;

const format = (x) => +formatEther(x);

const ENCODE_INPUT = [`int256[3][${LOOP_SIZE}]`];
const ENCODE_OUTPUT = [`int256[${LOOP_SIZE}]`];

const encode = (data, encodeType) => new AbiCoder().encode(encodeType, [data]);

const cdf = (x, mu, sigma) => gaussian(mu, sigma * sigma).cdf(x); //sigma**2 as gaussian takes variance

const generateInput = () => {
    const mu = Math.random() * 200 - 100; //mu in [-1e20, 1e20] for 18 decimal fixed point
    const sigma = Math.random() * 10; //sigma in (0, 1e19] for 18 decimal fixed point
    
    const uBound = mu + 10 * sigma; //x in [-1e23, 1e23], but if x is 10 (around 8.3 + error margin) sd away from the mean,
    const lBound = mu - 10 * sigma; //cdf is either 0 or 1, so we limit the x value in order to test for CDFs with output in [0,1], 
    const x = Math.random() * (uBound - lBound) + lBound //we test the other cases (x more than 10 sd away from the mean) through Fuzz Testing
    
    return [parse(x), parse(mu), parse(sigma)]
}

const generateOutput = (args) => {
    const x = format(args.at(0));
    const mu = format(args.at(1));
    const sigma = format(args.at(2));

    return parse(cdf(x, mu, sigma));
}

const main = () => {
    if (!fs.existsSync('./data/')) {
        fs.mkdirSync('./data/')
    }

    const inputs = [];
    const outputs = [];
    for (let i = 0; i < LOOP_SIZE; ++i) {
        const input = generateInput()
        const output = generateOutput(input)

        inputs.push(input)
        outputs.push(output)
    }

    const encodedInput = encode(inputs, ENCODE_INPUT);
    const encodedOutput = encode(outputs, ENCODE_OUTPUT);

    fs.writeFileSync(`./data/input`, encodedInput)
    fs.writeFileSync(`./data/output`, encodedOutput)
}

main();